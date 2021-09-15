require 'drum/model/playlist'
require 'drum/model/user'
require 'drum/model/track'
require 'drum/service/service'
require 'drum/utils/persist'
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

    limit_method :extract_spotify_features, rate: 15, interval: 5
    limit_method :all_spotify_playlist_tracks, rate: 15, interval: 5
    limit_method :all_spotify_saved_tracks, rate: 15, interval: 5
    limit_method :all_spotify_playlists, rate: 15, interval: 5
    limit_method :to_spotify_tracks, rate: 15, interval: 5
    limit_method :upload_playlist_tracks, rate: 15, interval: 5
    limit_method :upload_playlists, rate: 15, interval: 5

    # Initializes the Spotify service.
    #
    # @param [String] cache_dir The path to the cache directory (shared by all services)
    def initialize(cache_dir)
      @cache_dir = cache_dir / 'spotify'
      @cache_dir.mkdir unless @cache_dir.directory?

      @auth_tokens = PersistentHash.new(@cache_dir / 'auth-tokens.yaml')
    end

    def name
      'spotify'
    end

    # Authentication

    def authenticate_app(client_id, client_secret)
      RSpotify.authenticate(client_id, client_secret)
    end
    
    def authenticate_user(client_id, client_secret)
      existing = @auth_tokens[:latest]
      
      unless existing.nil? || existing[:expires_at] > (DateTime.now + (1800 / 86400.0)) # half an hour in days
        return existing[:access_token], existing[:refresh_token], existing[:token_type]
      end

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
      Launchy.open("https://accounts.spotify.com/authorize?client_id=#{client_id}&response_type=code&redirect_uri=http%3A%2F%2Flocalhost:#{port}%2Fcallback&scope=#{scopes.join('%20')}&state=#{csrf_state}")

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
        service_id: @service_id,
        access_token: access_token,
        refresh_token: refresh_token,
        token_type: token_type,
        expires_at: expires_at
      }
      puts "Successfully added access token that expires at #{expires_at}."
      
      return access_token, refresh_token, token_type
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
      client_id = ENV[CLIENT_ID_VAR]
      client_secret = ENV[CLIENT_SECRET_VAR]
      
      if client_id.nil? || client_secret.nil?
        raise "Please specify the env vars #{CLIENT_ID_VAR} and #{CLIENT_SECRET_VAR}!"
      end

      # TODO: Perform refresh flow if a valid token is in the DB

      self.authenticate_app(client_id, client_secret)
      access_token, refresh_token, token_type = self.authenticate_user(client_id, client_secret)
      me_json = self.fetch_me(access_token, token_type)
      
      @me_id = me_json['id']
      @me = RSpotify::User.new({
        'credentials' => {
          'token' => access_token,
          'refresh_token' => refresh_token,
          'access_refresh_callback' => Proc.new do |new_token, token_lifetime|
            new_expiry = DateTime.now + (token_lifetime / 86400.0)
            # TODO: Clean up old token
            @db[:auth_tokens].insert(
              service_id: @service_id,
              access_token: new_token,
              refresh_token: refresh_token, # TODO: Refresh token might change too
              token_type: token_type,
              expires_at: new_expiry
            )
          end
        },
        'id' => @me_id
      })
      
      puts "Successfully logged in to Spotify API as #{me_json['id']}."
    end

    # Utilities
    
    def all_spotify_playlists(offset: 0)
      playlists = @me.playlists(limit: PLAYLISTS_CHUNK_SIZE, offset: offset)
      unless playlists.empty?
        playlists + self.all_spotify_playlists(offset: offset + PLAYLISTS_CHUNK_SIZE)
      else
        []
      end
    end

    def all_spotify_playlist_tracks(playlist, offset: 0)
      tracks = playlist.tracks(limit: TRACKS_CHUNK_SIZE, offset: offset)
      unless tracks.empty?
        tracks + self.all_spotify_playlist_tracks(playlist, offset: offset + TRACKS_CHUNK_SIZE)
      else
        []
      end
    end

    def all_spotify_saved_tracks(offset: 0)
      tracks = @me.saved_tracks(limit: SAVED_TRACKS_CHUNKS_SIZE, offset: offset)
      unless tracks.empty?
        tracks + self.all_spotify_saved_tracks(offset: offset + SAVED_TRACKS_CHUNKS_SIZE)
      else
        []
      end
    end

    def extract_spotify_features(track)
      track&.audio_features
    end

    def hexdigest(x)
      Digest::SHA1.hexdigest(x)
    end

    # Download helpers

    def from_spotify_track(track, library_id = nil, options, output: method(:puts))
      new_track = Track.new(
        id: self.hexdigest(track.id),
        name: track.name,
        artist_ids: []
      )
      new_artists = []

      track.artists.each do |artist|
        new_artist = self.from_spotify_artist(artist)
        new_track.artist_ids << new_artist.id
      end

      # TODO: Audio features

      [new_track, new_artists]
    end

    # TODO: Store albums
    # TODO: Store artists

    def from_spotify_artist(artist)
      Artist.new(
        id: self.hexdigest(artist.id),
        name: artist.name,
        spotify: ArtistSpotify.new(
          id: artist.id
        )
      )
    end
    
    def from_spotify_user(user)
      # TODO: Fetch and store display name
      User.new(
        id: self.hexdigest(user.id),
        spotify: UserSpotify.new(
          id: user.id
        )
      )
    end

    def from_spotify_playlist(playlist, tracks = nil, library_id, options, output: method(:puts))
      new_playlist = Playlist.new(
        name: playlist.name,
        description: playlist&.description,
        spotify: PlaylistSpotify.new(
          id: playlist.id,
          public: playlist.public,
          collaborative: playlist.collaborative,
          image_url: playlist&.images.first&.dig('url')
        )
      )

      added_bys = playlist.tracks_added_by
      added_ats = playlist.tracks_added_at

      tracks = tracks || self.all_spotify_playlist_tracks(playlist)
      output.call "Storing #{tracks.length} playlist track(s)..."
      tracks.each_with_index do |track, i|
        # TODO: Make sure that added_at has the right type

        new_track, new_artists = self.from_spotify_track(track, playlist, options, output: method(:puts))
        new_track.added_at = added_ats[track.id]

        added_by = added_bys[track.id]
        unless added_by.nil?
          new_added_by = self.from_spotify_user(added_by)
          new_track.added_by = new_added_by.id
          new_track.store_user(new_added_by)
        end

        new_artists.each do |new_artist|
          new_playlist.store_artist(new_artist)
        end

        new_playlist.store_track(new_track)
      end

      new_playlist
    end

    # Upload helpers

    def to_spotify_tracks(tracks)
      unless tracks.nil? || tracks.empty?
        # TODO: If track has no ID, match it using search
        external_ids = tracks[...TO_SPOTIFY_TRACKS_CHUNK_SIZE].flat_map do |track|
          @db[:track_services].where(
            service_id: @service_id,
            track_id: track[:id]
          ).select_map(:external_id)
        end.to_a
        external_tracks = RSpotify::Track.find(external_ids)
        external_tracks + to_spotify_tracks(tracks[TO_SPOTIFY_TRACKS_CHUNK_SIZE...])
      else
        []
      end
    end

    def upload_playlist_tracks(external_tracks, external_playlist, options)
      unless external_tracks.nil? || external_tracks.empty?
        external_playlist.add_tracks!(external_tracks[...UPLOAD_PLAYLIST_TRACKS_CHUNK_SIZE])
        self.upload_playlist_tracks(external_tracks[UPLOAD_PLAYLIST_TRACKS_CHUNK_SIZE...], external_playlist, options)
      end
    end

    def upload_playlist(playlist, library_id, options, output: method(:puts))
      # TODO: Use actual description
      description = Time.now.strftime('Pushed with Drum on %Y-%m-%d.')
      external_playlist = @me.create_playlist!(playlist[:name], description: description, public: false, collaborative: false)

      tracks = @db[:playlist_tracks]
        .join(:tracks, id: :track_id)
        .where(playlist_id: playlist[:id])
        .order(:track_index)
        .to_a

      output.call "Externalizing #{tracks.length} playlist track(s)..."
      external_tracks = self.to_spotify_tracks(tracks)

      output.call "Uploading #{external_tracks.length} playlist track(s)..."
      self.upload_playlist_tracks(external_tracks, external_playlist, options)

      # TODO: Merging?
      self.from_spotify_playlist(external_playlist, external_tracks, library_id, options, output: output)
    end

    # Ref parsing

    def parse_resource_type(raw)
      case raw
      when 'playlist' then :playlist
      when 'album' then :album
      when 'track' then :track
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
        when "#{self.name}/liked" then :liked
        when "#{self.name}/playlists" then :playlists
        else return nil
        end
        Ref.new(self.name, :special, location)
      else
        self.parse_spotify_link(raw_ref.text) || self.parse_spotify_uri(raw_ref.text)
      end
    end

    # Service

    def preview(playlist_ref)
      puts(playlist_ref)

      # self.authenticate

      # playlists = self.all_spotify_playlists
      # puts playlists.map { |p| "Found playlist '#{p.name}' (#{p.total} track(s))" }
    end

    def pull(options)
      if options[:update_existing]
        puts 'Updates to existing tracks enabled.'
      end
      if options[:query_features]
        puts 'Audio feature querying enabled.'
      end

      self.authenticate

      user_id = self.store_user(@me)
      library_id = self.store_library(user_id)

      puts 'Querying saved tracks...'
      saved_tracks = self.all_spotify_saved_tracks

      puts 'Storing saved tracks...'
      bar = ProgressBar.new(saved_tracks.length)
      @db.transaction do
        saved_tracks.each do |track|
          self.from_spotify_track(track, library_id, options, output: bar.method(:puts))
          bar.increment!
        end
      end

      puts 'Querying playlists...'
      playlists = self.all_spotify_playlists

      puts 'Storing playlists...'
      bar = ProgressBar.new(playlists.length)
      playlists.each do |playlist|
        @db.transaction do
          self.from_spotify_playlist(playlist, library_id, options, output: bar.method(:puts))
          bar.increment!
        end
      end

      puts "Pulled #{playlists.length} playlist(s) from Spotify."

      # TODO: Handle merging?
    end

    def push(playlists, options)
      self.authenticate

      user_id = self.store_user(@me)
      library_id = self.store_library(user_id)

      # Note that pushes intentionally always create a new playlist
      # TODO: Flag for overwriting

      puts 'Uploading playlists...'
      bar = ProgressBar.new(playlists.length)
      playlists.each do |playlist|
        self.upload_playlist(playlist, library_id, options, output: bar.method(:puts))
        bar.increment!
      end
    end
  end
end
