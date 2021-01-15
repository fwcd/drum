require 'drum/services/service'
require 'json'
require 'launchy'
require 'rest-client'
require 'rspotify'
require 'securerandom'
require 'webrick'

module Drum
  class SpotifyService < Service
    NAME = 'Spotify'    
    PLAYLISTS_CHUNK_SIZE = 50
    TRACKS_CHUNK_SIZE = 100

    def initialize(db)
      @db = db
      service = db[:services].where(:name => NAME).first
      if service.nil?
        @service_id = db[:services].insert(:name => NAME)
      else
        @service_id = service[:id]
      end
    end

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
      client_id = ENV['SPOTIFY_CLIENT_ID']
      client_secret = ENV['SPOTIFY_CLIENT_SECRET']
      
      if client_id.nil? || client_secret.nil?
        raise 'Please specify the Spotify client id and secret in your env vars!'
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

    def all_tracks(playlist, offset: 0)
      tracks = playlist.tracks(limit: TRACKS_CHUNK_SIZE, offset: offset)
      unless tracks.empty?
        return tracks + self.all_tracks(playlist, offset: offset + TRACKS_CHUNK_SIZE)
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

    def store_track(track, skip_existing)
      # Check whether track already exists, i.e. find its
      # internal id. If so, update it!

      id = @db[:track_services].where(
        :service_id => @service_id,
        :external_id => track.id
      ).first&.dig(:track_id)

      unless !id.nil? && skip_existing
        features = track&.audio_features
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

        @db[:track_services].insert_conflict(:replace).insert(
          :service_id => @service_id,
          :track_id => id,
          :uri => track.uri,
          :external_id => track.id
        )
      end

      return id
    end

    # TODO: Store albums
    # TODO: Store artists
    # TODO: Figure out how tracks_added_by exactly works (i.e.
    #       if its keys are ids or full objects)
    
    def store_playlist_track(playlist, playlist_id, i, track, skip_existing)
      user = playlist.tracks_added_by[track.id]
      return @db[:playlist_tracks].insert_conflict(:replace).insert(
        :playlist_id => playlist_id,
        :track_id => self.store_track(track, skip_existing),
        :track_index => i,
        :added_at => playlist.tracks_added_at[track.id],
        :added_by => user && self.store_user(user)
      )
    end

    def store_playlist(playlist, skip_existing)
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

        self.all_tracks(playlist).each_with_index do |track, i|
          self.store_playlist_track(playlist, id, i, track, skip_existing)
        end

        return id
    end

    # CLI

    def preview
      self.authenticate

      playlists = self.all_playlists
      puts playlists.map { |p| "Found playlist '#{p.name}' (#{p.total} track(s))" }

      # DEBUG
      unless self.all_playlists.empty?
        p = playlists[0]
        tracks = p.tracks
        unless tracks.empty?
          t = tracks[0]
          puts "Snippet of #{p.name}'s first track: #{t.inspect} with features #{t.audio_features&.inspect}"
        end
      end
    end

    def pull(library_name, skip_existing)
      self.authenticate

      user_id = self.store_user(@me)

      playlists = self.all_playlists
      playlists.each_with_index do |playlist, i|
        puts "Storing playlist #{i + 1}/#{playlists.length} (#{playlist.total} track(s))..."
        self.store_playlist(playlist, skip_existing)
      end

      puts "Pulled #{playlists.length} playlist(s) from Spotify."

      # TODO: Handle merging?
    end
  end
end
