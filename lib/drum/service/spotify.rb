require 'drum/service/service'
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
    EXTERNALIZE_TRACKS_CHUNK_SIZE = 50
    UPLOAD_PLAYLIST_TRACKS_CHUNK_SIZE = 100

    CLIENT_ID_VAR = 'SPOTIFY_CLIENT_ID'
    CLIENT_SECRET_VAR = 'SPOTIFY_CLIENT_SECRET'

    # Rate-limiting for API-heavy methods
    # 'rate' describes the max. number of calls per interval (seconds)

    limit_method :extract_features, rate: 15, interval: 5
    limit_method :all_playlist_tracks, rate: 15, interval: 5
    limit_method :all_saved_tracks, rate: 15, interval: 5
    limit_method :all_playlists, rate: 15, interval: 5
    limit_method :externalize_tracks, rate: 15, interval: 5
    limit_method :upload_playlist_tracks, rate: 15, interval: 5
    limit_method :upload_playlists, rate: 15, interval: 5

    # Initializes the Spotify service.
    #
    # @param [String] cache_dir The path to the cache directory (shared by all services)
    def initialize(cache_dir)
      @cache_dir = "#{cache_dir}/spotify"
      Dir.mkdir(@cache_dir) unless Dir.exist?(@cache_dir)
    end

    def name
      'spotify'
    end

    # Authentication

    def authenticate_app(client_id, client_secret)
      RSpotify.authenticate(client_id, client_secret)
    end
    
    def authenticate_user(client_id, client_secret)
      existing = @db[:auth_tokens]
        .where(:service_id => @service_id)
        .where{expires_at > (DateTime.now + (1800 / 86400.0))} # half an hour in days
        .first
      
      unless existing.nil?
        return existing[:access_token], existing[:refresh_token], existing[:token_type]
      end

      # Generate a new access refresh token,
      # this might require user interaction. Since the
      # user has to authenticate through the browser
      # via Spotify's website, we use a small embedded
      # HTTP server as a 'callback'.

      port = 17998
      server = WEBrick::HTTPServer.new :Port => port
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
      
      @db[:auth_tokens].insert(
        :service_id => @service_id,
        :access_token => access_token,
        :refresh_token => refresh_token,
        :token_type => token_type,
        :expires_at => expires_at
      )
      puts "Successfully added access token that expires at #{expires_at}."
      
      return access_token, refresh_token, token_type
    end
    
    def fetch_me(access_token, token_type)
      auth_response = RestClient.get('https://api.spotify.com/v1/me', {
        :Authorization => "#{token_type} #{access_token}"
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
              :service_id => @service_id,
              :access_token => new_token,
              :refresh_token => refresh_token, # TODO: Refresh token might change too
              :token_type => token_type,
              :expires_at => new_expiry
            )
          end
        },
        'id' => @me_id
      })
      
      puts "Successfully logged in to Spotify API as #{me_json['id']}."
    end

    # Utilities
    
    def all_playlists(offset: 0)
      playlists = @me.playlists(limit: PLAYLISTS_CHUNK_SIZE, offset: offset)
      unless playlists.empty?
        return playlists + self.all_playlists(offset: offset + PLAYLISTS_CHUNK_SIZE)
      else
        return []
      end
    end

    def all_playlist_tracks(playlist, offset: 0)
      tracks = playlist.tracks(limit: TRACKS_CHUNK_SIZE, offset: offset)
      unless tracks.empty?
        return tracks + self.all_playlist_tracks(playlist, offset: offset + TRACKS_CHUNK_SIZE)
      else
        return []
      end
    end

    def all_saved_tracks(offset: 0)
      tracks = @me.saved_tracks(limit: SAVED_TRACKS_CHUNKS_SIZE, offset: offset)
      unless tracks.empty?
        return tracks + self.all_saved_tracks(offset: offset + SAVED_TRACKS_CHUNKS_SIZE)
      else
        return []
      end
    end

    def store_user(user)
      # Check whether user already exists, i.e. find its
      # internal id. If so, update it!
      
      id = @db[:user_services].where(
        :service_id => @service_id,
        :external_id => user.id
      ).first&.dig(:user_id)

      if id.nil?
        id = @db[:users].insert(
          :id => id
        )
      end

      @db[:user_services].insert_ignore.insert(
        :service_id => @service_id,
        :user_id => id,
        :external_id => user.id
        # TODO: Currently 404s
        # :display_name => user&.display_name
      )

      return id
    end

    def extract_features(track)
      return track&.audio_features
    end

    def store_track(track, library_id = nil, options, output: method(:puts))
      # Check whether track already exists, i.e. find its
      # internal id. If so, update it!

      unless track.id.nil?
        id = @db[:track_services].where(
          :service_id => @service_id,
          :external_id => track.id
        ).first&.dig(:track_id)
      else
        id = nil
      end

      if options[:update_existing] || id.nil?
        begin
          if options[:query_features]
            features = extract_features(track)
          else
            features = nil
          end
        rescue StandardError => e
          output.call "Got #{e} while querying audio features"
          features = nil
        end
        id = @db[:tracks].insert_conflict(:replace).insert(
          :id => id,
          :name => track.name,
          :duration_ms => track.duration_ms,
          :explicit => track.explicit,
          :isrc => track.external_ids['isrc'],
          :tempo => features&.tempo,
          :key => features&.key,
          :mode => features&.mode,
          :time_signature => features&.time_signature,
          :acousticness => features&.acousticness,
          :danceability => features&.danceability,
          :energy => features&.energy,
          :instrumentalness => features&.instrumentalness,
          :liveness => features&.liveness,
          :loudness => features&.loudness,
          :speechiness => features&.speechiness,
          :valence => features&.valence
        )
      end

      unless track.id.nil?
        @db[:track_services].insert_conflict(:replace).insert(
          :service_id => @service_id,
          :track_id => id,
          :uri => track.uri,
          :external_id => track.id
        )
      end

      unless library_id.nil?
        @db[:library_tracks].insert_ignore.insert(
          :library_id => library_id,
          :track_id => id
        )
      end

      return id
    end

    # TODO: Store albums
    # TODO: Store artists
    
    def store_playlist_track(i, track, added_at, added_by, playlist_id, library_id, options, output: method(:puts))
      return @db[:playlist_tracks].insert_conflict(:replace).insert(
        :playlist_id => playlist_id,
        :track_id => self.store_track(track, options, output: output),
        :track_index => i,
        :added_at => added_at,
        :added_by => added_by && self.store_user(added_by)
      )
    end

    def store_playlist(playlist, tracks = nil, library_id, options, output: method(:puts))
      # Check whether playlist already exists, i.e. find its
      # internal id. If so, update it!

      id = @db[:playlist_services].where(
        :service_id => @service_id,
        :external_id => playlist.id
      ).first&.dig(:playlist_id)

      id = @db[:playlists].insert_conflict(:replace).insert(
        :id => id,
        :name => playlist.name,
        :description => playlist&.description,
        :user_id => self.store_user(playlist.owner)
      )

      @db[:playlist_services].insert_conflict(:replace).insert(
        :service_id => @service_id,
        :playlist_id => id,
        :external_id => playlist.id,
        :uri => playlist.uri,
        :image_uri => playlist&.images.first&.dig('url'),
        :collaborative => playlist&.collaborative
      )

      @db[:library_playlists].insert_ignore.insert(
        :library_id => library_id,
        :playlist_id => id
      )

      added_by = playlist.tracks_added_by
      added_at = playlist.tracks_added_at

      tracks = tracks || self.all_playlist_tracks(playlist)
      output.call "Storing #{tracks.length} playlist track(s)..."
      tracks.each_with_index do |track, i|
        self.store_playlist_track(i, track, added_at[track.id], added_by[track.id], id, library_id, options, output: method(:puts))
      end

      return id
    end

    def store_library(user_id)
      @db[:libraries].insert_ignore.insert(
        :service_id => @service_id,
        :user_id => user_id,
        :name => self.name
      )

      return @db[:libraries].where(
        name: self.name,
        user_id: user_id,
        service_id: @service_id
      ).first[:id]
    end

    def externalize_tracks(tracks)
      unless tracks.nil? || tracks.empty?
        # TODO: If track has no ID, match it using search
        external_ids = tracks[...EXTERNALIZE_TRACKS_CHUNK_SIZE].flat_map do |track|
          @db[:track_services].where(
            service_id: @service_id,
            track_id: track[:id]
          ).select_map(:external_id)
        end.to_a
        external_tracks = RSpotify::Track.find(external_ids)
        return external_tracks + externalize_tracks(tracks[EXTERNALIZE_TRACKS_CHUNK_SIZE...])
      else
        return []
      end
    end

    def upload_playlist_tracks(external_tracks, external_playlist, options)
      unless external_tracks.nil? || external_tracks.empty?
        external_playlist.add_tracks!(external_tracks[...UPLOAD_PLAYLIST_TRACKS_CHUNK_SIZE])
        upload_playlist_tracks(external_tracks[UPLOAD_PLAYLIST_TRACKS_CHUNK_SIZE...], external_playlist, options)
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
      external_tracks = externalize_tracks(tracks)

      output.call "Uploading #{external_tracks.length} playlist track(s)..."
      upload_playlist_tracks(external_tracks, external_playlist, options)

      self.store_playlist(external_playlist, external_tracks, library_id, options, output: output)
    end

    # CLI

    def preview
      self.authenticate

      playlists = self.all_playlists
      puts playlists.map { |p| "Found playlist '#{p.name}' (#{p.total} track(s))" }
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
      saved_tracks = self.all_saved_tracks

      puts 'Storing saved tracks...'
      bar = ProgressBar.new(saved_tracks.length)
      @db.transaction do
        saved_tracks.each do |track|
          self.store_track(track, library_id, options, output: bar.method(:puts))
          bar.increment!
        end
      end

      puts 'Querying playlists...'
      playlists = self.all_playlists

      puts 'Storing playlists...'
      bar = ProgressBar.new(playlists.length)
      playlists.each do |playlist|
        @db.transaction do
          self.store_playlist(playlist, library_id, options, output: bar.method(:puts))
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
