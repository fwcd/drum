require 'drum/service/service'
require 'jwt'
require 'rest-client'
require 'launchy'
require 'ruby-limiter'
require 'webrick'

module Drum
  # A service implementation that uses the Apple Music API to query playlists.
  class AppleMusicService < Service
    extend Limiter::Mixin

    BASE_URL = 'https://api.music.apple.com/v1'
    PLAYLISTS_CHUNK_SIZE = 50

    MUSICKIT_P8_FILE_VAR = 'MUSICKIT_KEY_P8_FILE_PATH'
    MUSICKIT_KEY_VAR = 'MUSICKIT_KEY_ID'
    MUSICKIT_TEAM_ID_VAR = 'MUSICKIT_TEAM_ID'

    # Rate-limiting for API-heavy methods

    limit_method :library_playlists, rate: 60
    limit_method :library_playlist_tracks, rate: 60

    # Initializes the Apple Music service.
    #
    # @param [String] cache_dir The path to the cache directory (shared by all services)
    def initialize(cache_dir)
      @cache_dir = "#{cache_dir}/applemusic"
      Dir.mkdir(@cache_dir) unless Dir.exist?(@cache_dir)
    end

    def name
      'applemusic'
    end

    # Authentication

    def authenticate_app(p8_file, key_id, team_id)
      # TODO: Store and reuse keys in DB instead of regenerating a new one each time

      expiration_in_days = 180 # may not be greater than 180

      # Source: https://github.com/mkoehnke/musickit-token-encoder/blob/master/musickit-token-encoder
      # Copyright (c) 2016 Mathias Koehnke (http://www.mathiaskoehnke.de)
      #
      # Permission is hereby granted, free of charge, to any person obtaining a copy
      # of this software and associated documentation files (the "Software"), to deal
      # in the Software without restriction, including without limitation the rights
      # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
      # copies of the Software, and to permit persons to whom the Software is
      # furnished to do so, subject to the following conditions:
      #
      # The above copyright notice and this permission notice shall be included in
      # all copies or substantial portions of the Software.
      #
      # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
      # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
      # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
      # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
      # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
      # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
      # THE SOFTWARE.

      iat = Time.now.to_i
      exp = (Time.now + expiration_in_days * 86400).to_i 
      pem_file = `openssl pkcs8 -nocrypt -in #{p8_file}`
      private_key = OpenSSL::PKey::EC.new(pem_file) 
      payload = {:iss => "#{team_id}", :iat => iat, :exp => exp}
      return JWT.encode(payload, private_key, "ES256", { alg: "ES256", kid: "#{key_id}" })
    end

    def authenticate_user(token)
      # TODO: Store this token in the DB

      # Generate a new access refresh token,
      # this might require user interaction. Since the
      # user has to authenticate through the browser
      # via Spotify's website, we use a small embedded
      # HTTP server as a 'callback'.

      port = 17997
      server = WEBrick::HTTPServer.new :Port => port
      user_token = nil

      server.mount_proc '/' do |req, res|
        res.content_type = 'text/html'
        res.body = [
          '<!DOCTYPE html>',
          '<html>',
          '  <head>',
          '    <script src="https://js-cdn.music.apple.com/musickit/v1/musickit.js"></script>',
          '    <script>',
          "      document.addEventListener('musickitloaded', () => {",
          '        MusicKit.configure({',
          "          developerToken: '#{token}',",
          "          app: { name: 'Drum', build: '0.0.1' }",
          '        });',
          '      });',
          "      window.addEventListener('load', () => {",
          "        document.getElementById('authbutton').addEventListener('click', () => {",
          '          MusicKit.getInstance()',
          '            .authorize()',
          "            .then(userToken => fetch('/callback', { method: 'POST', body: userToken }))",
          "            .then(response => { document.getElementById('status').innerText = 'Done!'; });",
          '        });',
          '      });',
          '    </script>',
          '  </head>',
          '  <body>',
          '    <div id="status"><button id="authbutton">Click me to authorize!</button></div>',
          '  </body>',
          '</html>'
        ].join("\n")
      end

      server.mount_proc '/callback' do |req, res|
        user_token = req.body
        unless user_token.nil? || user_token.empty?
          res.body = 'Successfully got user token!'
        else
          res.body = 'Did not get user token! :('
        end
        server.shutdown
      end

      Thread.new do
        sleep(1) # a short delay to make sure that the web server has launched
        Launchy.open("http://localhost:#{port}/")
      end

      trap 'INT' do server.shutdown end
      
      puts "Launching callback HTTP server on port #{port}, waiting for auth code..."
      server.start

      if user_token.nil?
        raise "Did not get a MusicKit user token."
      end

      return user_token
    end

    def authenticate
      p8_file = ENV[MUSICKIT_P8_FILE_VAR]
      key_id = ENV[MUSICKIT_KEY_VAR]
      team_id = ENV[MUSICKIT_TEAM_ID_VAR]

      if p8_file.nil? || key_id.nil? || team_id.nil?
        raise "Please specify your MusicKit keys (#{MUSICKIT_P8_FILE_VAR}, #{MUSICKIT_KEY_ID_VAR}, #{MUSICKIT_TEAM_ID_VAR}) in your env vars!"
      end

      token = self.authenticate_app(p8_file, key_id, team_id)
      puts "Generated MusicKit JWT token #{token}"

      user_token = self.authenticate_user(token)
      puts "Generated MusicKit user token #{user_token}"

      @token = token
      @user_token = user_token
    end

    # Apple Music API

    def request(method, endpoint)
      RestClient::Request.execute(
        method: method,
        url: "#{BASE_URL}#{endpoint}",
        headers: {
          'Authorization': "Bearer #{@token}",
          'Music-User-Token': @user_token
        }
      )
    end

    def get_json(endpoint)
      response = request(:get, endpoint)
      unless response.code >= 200 && response.code < 300
        raise "Something went wrong while GETting #{endpoint}: #{response}"
      end
      return JSON.parse(response.body)
    end

    def library_playlists(offset: 0)
      get_json("/me/library/playlists?limit=#{PLAYLISTS_CHUNK_SIZE}&offset=#{offset}")
    end

    def library_playlist_tracks(playlist, offset: 0)
      get_json("/me/library/playlists/#{playlist['id']}/tracks?limit=#{PLAYLISTS_CHUNK_SIZE}&offset=#{offset}")
    end

    # Utilities

    def all_library_playlists(offset: 0, total: nil)
      unless total != nil && offset >= total
        response = self.library_playlists(offset: offset)
        playlists = response['data']
        unless playlists.empty?
          return playlists + self.all_library_playlists(offset: offset + PLAYLISTS_CHUNK_SIZE, total: response.dig('meta', 'total'))
        end
      end
      return []
    end

    def all_library_playlist_tracks(playlist, offset: 0, total: nil)
      unless total != nil && offset >= total
        response = self.library_playlist_tracks(playlist, offset: offset)
        tracks = response['data']
        unless tracks.empty?
          return tracks + self.all_library_playlist_tracks(playlist, offset: offset + PLAYLISTS_CHUNK_SIZE, total: response.dig('meta', 'total'))
        end
      end
      return []
    end

    def store_library_track(track, library_id, update_existing)
      # Check whether track already exists, i.e. find its
      # internal id. If so, update it!

      # We store the catalog ID rather than the (external) library-specific ID
      # to make it easy to query more metadata later.
      catalog_id = track.dig('attributes', 'playParams', 'catalogId')

      id = @db[:track_services].where(
        :service_id => @service_id,
        :external_id => catalog_id
      ).first&.dig(:track_id)

      if update_existing || id.nil?
        id = @db[:tracks].insert_conflict(:replace).insert(
          :id => id,
          :name => track.dig('attributes', 'name'),
          :duration_ms => track.dig('attributes', 'durationInMillis'),
        )
      end

      @db[:track_services].insert_conflict(:replace).insert(
        :service_id => @service_id,
        :track_id => id,
        :external_id => catalog_id
      )

      @db[:library_tracks].insert_ignore.insert(
        :library_id => library_id,
        :track_id => id
      )

      return id
    end

    # TODO: Make batch queries for catalog tracks to fetch details later
    # (https://developer.apple.com/documentation/applemusicapi/get_multiple_catalog_songs_by_id)

    def store_library_playlist_track(i, track, playlist_id, library_id, update_existing)
      return @db[:playlist_tracks].insert_conflict(:replace).insert(
        :playlist_id => playlist_id,
        :track_id => self.store_library_track(track, library_id, update_existing),
        :track_index => i
      )
    end

    def store_library_playlist(playlist, library_id, update_existing)
      # Check whether playlist already exists, i.e. find its
      # internal id. If so, update it!

      id = @db[:playlist_services].where(
        :service_id => @service_id,
        :external_id => playlist['id']
      ).first&.dig(:playlist_id)

      id = @db[:playlists].insert_conflict(:replace).insert(
        :id => id,
        :name => playlist.dig('attributes', 'name'),
        :description => playlist.dig('attributes', 'description', 'standard')
      )

      @db[:playlist_services].insert_conflict(:replace).insert(
        :service_id => @service_id,
        :playlist_id => id,
        :external_id => playlist['id']
        # TODO: URI/Images?
      )

      @db[:library_playlists].insert_ignore.insert(
        :library_id => library_id,
        :playlist_id => id
      )

      tracks = self.all_library_playlist_tracks(playlist)
      tracks.each_with_index do |track, i|
        puts "  Storing track #{i + 1}/#{tracks.length}..."
        self.store_library_playlist_track(i, track, id, library_id, update_existing)
      end

      return id
    end

    def store_library
      @db[:libraries].insert_ignore.insert(
        :service_id => @service_id,
        :name => self.name
      )
      return @db[:libraries].where(service_id: @service_id, name: self.name).first[:id]
    end

    # CLI

    def preview
      self.authenticate

      self.all_library_playlists.each do |playlist|
        puts "Found playlist #{playlist.dig('attributes', 'name')}."
      end
    end

    def pull(options)
      update_existing = options[:update_existing]
      if update_existing
        puts 'Updating existing tracks.'
      end

      self.authenticate
      
      library_id = self.store_library

      playlists = self.all_library_playlists
      playlists.each_with_index do |playlist, i|
        puts "Storing playlist #{i + 1}/#{playlists.length} '#{playlist.dig('attributes', 'name')}'..."
        @db.transaction do
          # TODO: Debug ForeignKeyConstraintViolation, apparently
          # happens on line 275 in `store_library_playlist'
          self.store_library_playlist(playlist, library_id, update_existing)
        end
      end
    end
  end
end
