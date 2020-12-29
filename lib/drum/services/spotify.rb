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

      port = 17998 # TODO: Dynamically generate a port
      server = WEBrick::HTTPServer.new :Port => 17998
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
      
      # TODO: Perform refresh flow if a valid token is in the DB

      self.authenticate_app(client_id, client_secret)
      access_token, refresh_token, token_type = self.authenticate_user(client_id, client_secret)
      me_json = self.fetch_me(access_token, token_type)
      
      if client_id.nil? || client_secret.nil?
        raise 'Please specify the Spotify client id and secret in your env vars!'
      end

      @me = RSpotify::User.new({
        'credentials': {
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
        'id' => me_json['id']
      })
      
      puts "Successfully logged in to Spotify API as #{me_json['id']}."
    end

    def preview
      self.authenticate
      puts @me.playlists.map { |p| "Found playlist '#{p.name}'" }
    end
  end
end
