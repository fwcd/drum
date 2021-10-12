require 'drum/model/album'
require 'drum/model/playlist'
require 'drum/model/user'
require 'drum/model/track'
require 'drum/service/service'
require 'drum/utils/persist'
require 'base64'
require 'digest'
require 'json'
require 'launchy'
require 'rest-client'
require 'rspotify'
require 'ruby-limiter'
require 'progress_bar'
require 'securerandom'
require 'webrick'

module Drum
  # A service implementation that uses the Spotify Web API to query playlists.
  class SpotifyService < Service
    extend Limiter::Mixin

    PLAYLISTS_CHUNK_SIZE = 50
    TRACKS_CHUNK_SIZE = 100
    SAVED_TRACKS_CHUNKS_SIZE = 50
    TO_SPOTIFY_TRACKS_CHUNK_SIZE = 50
    UPLOAD_PLAYLIST_TRACKS_CHUNK_SIZE = 100

    CLIENT_ID_VAR = 'SPOTIFY_CLIENT_ID'
    CLIENT_SECRET_VAR = 'SPOTIFY_CLIENT_SECRET'

    # Rate-limiting for API-heavy methods
    # 'rate' describes the max. number of calls per interval (seconds)

    limit_method :extract_sp_features, rate: 15, interval: 5
    limit_method :all_sp_playlist_tracks, rate: 15, interval: 5
    limit_method :all_sp_library_tracks, rate: 15, interval: 5
    limit_method :all_sp_library_playlists, rate: 15, interval: 5
    limit_method :to_sp_tracks, rate: 15, interval: 5
    limit_method :upload_sp_playlist_tracks, rate: 15, interval: 5
    limit_method :upload_playlist, rate: 15, interval: 5

    # Initializes the Spotify service.
    #
    # @param [String] cache_dir The path to the cache directory (shared by all services)
    # @param [Boolean] fetch_artist_images Whether to fetch artist images (false by default)
    def initialize(cache_dir, fetch_artist_images: false)
      @cache_dir = cache_dir / self.name
      @cache_dir.mkdir unless @cache_dir.directory?

      @auth_tokens = PersistentHash.new(@cache_dir / 'auth-tokens.yaml')
      @authenticated = false

      @fetch_artist_images = fetch_artist_images
    end

    def name
      'spotify'
    end

    # Authentication

    def authenticate_app(client_id, client_secret)
      RSpotify.authenticate(client_id, client_secret)
    end

    def consume_authentication_response(auth_response)
      unless auth_response.code >= 200 && auth_response.code < 300
        raise "Something went wrong while fetching auth token: #{auth_response}"
      end

      auth_json = JSON.parse(auth_response.body)
      access_token = auth_json['access_token']
      refresh_token = auth_json['refresh_token']
      token_type = auth_json['token_type']
      expires_in = auth_json['expires_in'] # seconds
      expires_at = DateTime.now + (expires_in / 86400.0)
      
      @auth_tokens[:latest] = {
        access_token: access_token,
        refresh_token: refresh_token || @auth_tokens[:latest][:refresh_token],
        token_type: token_type,
        expires_at: expires_at
      }
      puts "Successfully added access token that expires at #{expires_at}."
      
      [access_token, refresh_token, token_type]
    end

    def authenticate_user_via_browser(client_id, client_secret)
      # Generate a new access refresh token,
      # this might require user interaction. Since the
      # user has to authenticate through the browser
      # via Spotify's website, we use a small embedded
      # HTTP server as a 'callback'.

      port = 17998
      server = WEBrick::HTTPServer.new Port: port
      csrf_state = SecureRandom.hex
      auth_code = nil
      error = nil
      
      server.mount_proc '/callback' do |req, res|
        error = req.query['error']
        auth_code = req.query['code']
        csrf_response = req.query['state']
        
        if error.nil? && !auth_code.nil? && csrf_response == csrf_state
          res.body = 'Successfully got authorization code!'
        else
          res.body = "Could not authorize: #{error} Sorry :("
        end

        server.shutdown
      end
      
      scopes = [
        # Listening History
        'user-read-recently-played',
        'user-top-read',
        # Playlists
        'playlist-modify-private',
        'playlist-read-private',
        'playlist-read-collaborative',
        # Library
        'user-library-modify',
        'user-library-read',
        # User
        'user-read-private'
      ]
      authorize_url = "https://accounts.spotify.com/authorize?client_id=#{client_id}&response_type=code&redirect_uri=http%3A%2F%2Flocalhost:#{port}%2Fcallback&scope=#{scopes.join('%20')}&state=#{csrf_state}"
      Launchy.open(authorize_url)

      trap 'INT' do server.shutdown end
      
      puts "Launching callback HTTP server on port #{port}, waiting for auth code..."
      server.start
      
      if auth_code.nil?
        raise "Did not get an auth code: #{error}"
      end

      auth_response = RestClient.post('https://accounts.spotify.com/api/token', {
        grant_type: 'authorization_code',
        code: auth_code,
        redirect_uri: "http://localhost:#{port}/callback", # validation only
        client_id: client_id,
        client_secret: client_secret
      })
      
      self.consume_authentication_response(auth_response)
    end

    def authenticate_user_via_refresh(client_id, client_secret, refresh_token)
      # Authenticate the user using an existing (cached)
      # refresh token. This is useful if the user already
      # has been authenticated or a non-interactive authentication
      # is required (e.g. in a CI script).
      encoded = Base64.strict_encode64("#{client_id}:#{client_secret}")
      auth_response = RestClient.post('https://accounts.spotify.com/api/token', {
        grant_type: 'refresh_token',
        refresh_token: refresh_token
      }, {
        'Authorization' => "Basic #{encoded}"
      })

      self.consume_authentication_response(auth_response)
    end

    def authenticate_user(client_id, client_secret)
      existing = @auth_tokens[:latest]

      unless existing.nil? || existing[:expires_at].nil? || existing[:expires_at] < DateTime.now
        puts 'Skipping authentication...'
        return existing[:access_token], existing[:refresh_token], existing[:token_type]
      end

      unless existing.nil? || existing[:refresh_token].nil?
        puts 'Authenticating via refresh...'
        self.authenticate_user_via_refresh(client_id, client_secret, existing[:refresh_token])
      else
        puts 'Authenticating via browser...'
        self.authenticate_user_via_browser(client_id, client_secret)
      end
    end
    
    def fetch_me(access_token, token_type)
      auth_response = RestClient.get('https://api.spotify.com/v1/me', {
        Authorization: "#{token_type} #{access_token}"
      })
      
      unless auth_response.code >= 200 && auth_response.code < 300
        raise "Something went wrong while user data: #{auth_response}"
      end
      
      return JSON.parse(auth_response.body)
    end

    def authenticate
      if @authenticated
        return
      end

      client_id = ENV[CLIENT_ID_VAR]
      client_secret = ENV[CLIENT_SECRET_VAR]
      
      if client_id.nil? || client_secret.nil?
        raise "Please specify the env vars #{CLIENT_ID_VAR} and #{CLIENT_SECRET_VAR}!"
      end

      self.authenticate_app(client_id, client_secret)
      access_token, refresh_token, token_type = self.authenticate_user(client_id, client_secret)

      me_json = self.fetch_me(access_token, token_type)
      me_json['credentials'] = {
        'token' => access_token,
        'refresh_token' => refresh_token,
        'access_refresh_callback' => Proc.new do |new_token, token_lifetime|
          new_expiry = DateTime.now + (token_lifetime / 86400.0)
          @auth_tokens[:latest] = {
            access_token: new_token,
            refresh_token: refresh_token, # TODO: Refresh token might change too
            token_type: token_type,
            expires_at: new_expiry
          }
        end
      }
      
      @me = RSpotify::User.new(me_json)
      @authenticated = true

      puts "Successfully logged in to Spotify API as #{me_json['id']}."
    end

    # Download helpers
    
    def all_sp_library_playlists(offset: 0)
      sp_playlists = @me.playlists(limit: PLAYLISTS_CHUNK_SIZE, offset: offset)
      unless sp_playlists.empty?
        sp_playlists + self.all_sp_library_playlists(offset: offset + PLAYLISTS_CHUNK_SIZE)
      else
        []
      end
    end

    def all_sp_playlist_tracks(sp_playlist, offset: 0)
      sp_tracks = sp_playlist.tracks(limit: TRACKS_CHUNK_SIZE, offset: offset)
      unless sp_tracks.empty?
        sp_tracks + self.all_sp_playlist_tracks(sp_playlist, offset: offset + TRACKS_CHUNK_SIZE)
      else
        []
      end
    end

    def all_sp_library_tracks(offset: 0)
      sp_tracks = @me.saved_tracks(limit: SAVED_TRACKS_CHUNKS_SIZE, offset: offset)
      unless sp_tracks.empty?
        sp_tracks + self.all_sp_library_tracks(offset: offset + SAVED_TRACKS_CHUNKS_SIZE)
      else
        []
      end
    end

    def extract_sp_features(sp_track)
      sp_track&.audio_features
    end

    # Note that while the `from_sp_*` methods use
    # an existing `new_playlist` to reuse albums/artists/etc,
    # they do not mutate the `new_playlist` themselves.

    # TODO: Replace hexdigest id generation with something
    #       that matches e.g. artists or albums with those
    #       already in the playlist.

    def from_sp_id(sp_id, new_playlist)
      unless sp_id.nil?
        Digest::SHA1.hexdigest(sp_id)
      else
        nil
      end
    end

    def from_sp_album(sp_album, new_playlist, output: method(:puts))
      new_id = self.from_sp_id(sp_album.id, new_playlist)
      new_album = new_playlist.albums[new_id]
      unless new_album.nil?
        return [new_album, []]
      end

      new_album = Album.new(
        id: self.from_sp_id(sp_album.id, new_playlist),
        name: sp_album.name,
        spotify: AlbumSpotify.new(
          id: sp_album.id,
          image_url: sp_album&.images.first&.dig('url')
        )
      )

      new_artists = sp_album.artists.map do |sp_artist|
        new_artist = self.from_sp_artist(sp_artist, new_playlist)
        new_album.artist_ids << new_artist.id
        new_artist
      end

      [new_album, new_artists]
    end

    def from_sp_track(sp_track, new_playlist, output: method(:puts))
      new_track = Track.new(
        name: sp_track.name,
        duration_ms: sp_track.duration_ms,
        explicit: sp_track.explicit,
        isrc: sp_track.external_ids&.dig('isrc'),
        spotify: TrackSpotify.new(
          id: sp_track.id
        )
      )

      new_artists = sp_track.artists.map do |sp_artist|
        new_artist = self.from_sp_artist(sp_artist, new_playlist)
        new_track.artist_ids << new_artist.id
        new_artist
      end

      new_album, new_album_artists = self.from_sp_album(sp_track.album, new_playlist, output: output)
      new_track.album_id = new_album.id
      new_artists += new_album_artists

      # TODO: Audio features

      [new_track, new_artists, new_album]
    end

    def from_sp_artist(sp_artist, new_playlist)
      new_id = self.from_sp_id(sp_artist.id, new_playlist)
      new_playlist.artists[new_id] || Artist.new(
        id: new_id,
        name: sp_artist.name,
        spotify: ArtistSpotify.new(
          id: sp_artist.id,
          image_url: if @fetch_artist_images
            sp_artist&.images.first&.dig('url')
          else
            nil
          end
        )
      )
    end
    
    def from_sp_user(sp_user, new_playlist)
      new_id = self.from_sp_id(sp_user.id, new_playlist)
      new_playlist.users[new_id] || User.new(
        id: self.from_sp_id(sp_user.id, new_playlist),
        display_name: begin
          sp_user.display_name unless sp_user.id.empty?
        rescue StandardError => e
          nil
        end,
        spotify: UserSpotify.new(
          id: sp_user.id,
          image_url: begin
            sp_user&.images.first&.dig('url')
          rescue StandardError => e
            nil
          end
        )
      )
    end

    def from_sp_playlist(sp_playlist, sp_tracks = nil, output: method(:puts))
      new_playlist = Playlist.new(
        name: sp_playlist.name,
        description: sp_playlist&.description,
        spotify: PlaylistSpotify.new(
          id: sp_playlist.id,
          public: sp_playlist.public,
          collaborative: sp_playlist.collaborative,
          image_url: begin
            sp_playlist&.images.first&.dig('url')
          rescue StandardError => e
            nil
          end
        )
      )

      new_playlist.id = self.from_sp_id(sp_playlist.id, new_playlist)

      sp_author = sp_playlist&.owner
      unless sp_author.nil?
        new_author = self.from_sp_user(sp_author, new_playlist)
        new_playlist.author_id = new_author.id
        new_playlist.store_user(new_author)
      end

      sp_added_bys = sp_playlist.tracks_added_by
      sp_added_ats = sp_playlist.tracks_added_at

      sp_tracks = sp_tracks || self.all_sp_playlist_tracks(sp_playlist)
      output.call "Got #{sp_tracks.length} playlist track(s) for '#{sp_playlist.name}'..."
      sp_tracks.each do |sp_track|
        new_track, new_artists, new_album = self.from_sp_track(sp_track, new_playlist, output: output)
        new_track.added_at = sp_added_ats[sp_track.id]

        sp_added_by = sp_added_bys[sp_track.id]
        unless sp_added_by.nil?
          new_added_by = self.from_sp_user(sp_added_by, new_playlist)
          new_track.added_by = new_added_by.id
          new_playlist.store_user(new_added_by)
        end

        new_artists.each do |new_artist|
          new_playlist.store_artist(new_artist)
        end

        new_playlist.store_album(new_album)
        new_playlist.store_track(new_track)
      end

      new_playlist
    end

    # Upload helpers

    def to_sp_tracks(tracks)
      unless tracks.nil? || tracks.empty?
        # TODO: If track has no ID, match it using search
        sp_ids = tracks[...TO_SPOTIFY_TRACKS_CHUNK_SIZE].filter_map { |t| t&.spotify&.id }
        sp_tracks = RSpotify::Track.find(sp_ids)
        sp_tracks + to_sp_tracks(tracks[TO_SPOTIFY_TRACKS_CHUNK_SIZE...])
      else
        []
      end
    end

    def upload_sp_playlist_tracks(sp_tracks, sp_playlist)
      unless sp_tracks.nil? || sp_tracks.empty?
        sp_playlist.add_tracks!(sp_tracks[...UPLOAD_PLAYLIST_TRACKS_CHUNK_SIZE])
        self.upload_sp_playlist_tracks(sp_tracks[UPLOAD_PLAYLIST_TRACKS_CHUNK_SIZE...], sp_playlist)
      end
    end

    def upload_playlist(playlist, output: method(:puts))
      # TODO: Use actual description
      description = Time.now.strftime('Pushed with Drum on %Y-%m-%d.')
      sp_playlist = @me.create_playlist!(playlist.name, description: description, public: false, collaborative: false)

      tracks = playlist.tracks

      output.call "Externalizing #{tracks.length} playlist track(s)..."
      sp_tracks = self.to_sp_tracks(tracks)

      output.call "Uploading #{sp_tracks.length} playlist track(s)..."
      self.upload_sp_playlist_tracks(sp_tracks, sp_playlist)

      # TODO: Clone the original playlist and insert potentially new Spotify ids
      nil
    end

    # Ref parsing

    def parse_resource_type(raw)
      case raw
      when 'playlist' then :playlist
      when 'album' then :album
      when 'track' then :track
      when 'user' then :user
      when 'artist' then :artist
      else nil
      end
    end

    def parse_spotify_link(raw)
      uri = URI(raw)
      unless ['http', 'https'].include?(uri&.scheme) && uri&.host == 'open.spotify.com'
        return nil
      end

      parsed_path = uri.path.split('/')
      unless parsed_path.length == 3
        return nil
      end

      resource_type = self.parse_resource_type(parsed_path[1])
      resource_location = parsed_path[2]

      Ref.new(self.name, resource_type, resource_location)
    end

    def parse_spotify_uri(raw)
      uri = URI(raw)
      unless uri&.scheme == 'spotify'
        return nil
      end

      parsed_path = uri.opaque.split(':')
      unless parsed_path.length == 2
        return nil
      end

      resource_type = self.parse_resource_type(parsed_path[0])
      resource_location = parsed_path[1]

      Ref.new(self.name, resource_type, resource_location)
    end

    def parse_ref(raw_ref)
      if raw_ref.is_token
        location = case raw_ref.text
        when "#{self.name}/tracks" then :tracks
        when "#{self.name}/playlists" then :playlists
        else return nil
        end
        Ref.new(self.name, :special, location)
      else
        self.parse_spotify_link(raw_ref.text) || self.parse_spotify_uri(raw_ref.text)
      end
    end

    # Service

    def download(ref)
      self.authenticate

      case ref.resource_type
      when :special
        case ref.resource_location
        when :playlists
          puts 'Querying playlists...'
          sp_playlists = self.all_sp_library_playlists

          puts 'Fetching playlists...'
          bar = ProgressBar.new(sp_playlists.length)

          Enumerator.new do |enum|
            sp_playlists.each do |sp_playlist|
              new_playlist = self.from_sp_playlist(sp_playlist, output: bar.method(:puts))
              bar.increment!
              enum.yield new_playlist
            end
          end
        when :tracks
          puts 'Querying saved tracks...'
          sp_saved_tracks = self.all_sp_library_tracks

          puts 'Fetching saved tracks...'
          bar = ProgressBar.new(sp_saved_tracks.length)
          new_playlist = Playlist.new(
            name: 'Saved Tracks'
          )
          new_me = self.from_sp_user(@me, new_playlist)
          new_playlist.id = self.from_sp_id(new_me.id, new_playlist)
          new_playlist.author_id = new_me.id
          new_playlist.store_user(new_me)

          sp_saved_tracks.each do |sp_track|
            new_track, new_artists, new_album = self.from_sp_track(sp_track, new_playlist, output: bar.method(:puts))

            new_artists.each do |new_artist|
              new_playlist.store_artist(new_artist)
            end

            new_playlist.store_album(new_album)
            new_playlist.store_track(new_track)

            bar.increment!
          end

          [new_playlist]
        else raise "Special resource location '#{ref.resource_location}' cannot be downloaded (yet)"
        end
      when :playlist
        playlist = RSpotify::Playlist.find_by_id(ref.resource_location)
        new_playlist = self.from_sp_playlist(playlist)

        [new_playlist]
      else raise "Resource type '#{ref.resource_type}' cannot be downloaded (yet)"
      end
    end

    def upload(ref, playlists)
      self.authenticate

      # Note that pushes currently intentionally always create a new playlist
      # TODO: Flag for overwriting (something like -f, --force?)

      unless ref.resource_type == :special && ref.resource_location == :playlists
        raise 'Cannot upload to anything other than @spotify/playlists yet!'
      end

      puts "Uploading #{playlists.length} playlist(s)..."
      bar = ProgressBar.new(playlists.length)
      playlists.each do |playlist|
        self.upload_playlist(playlist, output: bar.method(:puts))
        bar.increment!
      end
    end
  end
end
