require 'drum/model/artist'
require 'drum/model/ref'
require 'drum/model/playlist'
require 'drum/model/track'
require 'drum/service/service'
require 'jwt'
require 'json'
require 'launchy'
require 'rest-client'
require 'ruby-limiter'
require 'webrick'

module Drum
  # A service that uses the Apple Music API to query playlists.
  class AppleMusicService < Service
    extend Limiter::Mixin

    BASE_URL = 'https://api.music.apple.com/v1'
    PLAYLISTS_CHUNK_SIZE = 50

    MUSICKIT_P8_FILE_VAR = 'MUSICKIT_KEY_P8_FILE_PATH'
    MUSICKIT_KEY_VAR = 'MUSICKIT_KEY_ID'
    MUSICKIT_TEAM_ID_VAR = 'MUSICKIT_TEAM_ID'

    # Rate-limiting for API-heavy methods

    # TODO

    # Initializes the Apple Music service.
    #
    # @param [String] cache_dir The path to the cache directory (shared by all services)
    def initialize(cache_dir)
      @cache_dir = cache_dir / self.name
      @cache_dir.mkdir unless @cache_dir.directory?

      @auth_tokens = PersistentHash.new(@cache_dir / 'auth-tokens.yaml')
      @authenticated = false
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

    # Ref parsing

    def parse_ref(raw_ref)
      # TODO: Implement proper ref parsing
      if raw_ref.is_token && raw_ref.text == 'applemusic'
        Ref.new(self.name, :playlist, '')
      else
        nil
      end
    end

    # Service

    def download(ref)
      self.authenticate

      # TODO: Implement proper downloading
      []
    end
  end
end
