require 'drum/model/album'
require 'drum/model/artist'
require 'drum/model/ref'
require 'drum/model/playlist'
require 'drum/model/track'
require 'drum/service/service'
require 'drum/utils/persist'
require 'drum/version'
require 'date'
require 'digest'
require 'jwt'
require 'json'
require 'launchy'
require 'progress_bar'
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

    # Rate-limiting for API methods

    limit_method :api_library_playlists, rate: 60
    limit_method :api_library_playlist_tracks, rate: 60

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
      existing = @auth_tokens[:app]

      unless existing.nil? || existing[:expires_at].nil? || existing[:expires_at] < DateTime.now
        puts 'Skipping app authentication...'
        return existing[:token]
      end

      expiration_in_days = 180 # may not be greater than 180
      expiration_in_seconds = expiration_in_days * 86400

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
      exp = (Time.now + expiration_in_seconds).to_i 
      pem_file = `openssl pkcs8 -nocrypt -in #{p8_file}`
      private_key = OpenSSL::PKey::EC.new(pem_file) 
      payload = { iss: "#{team_id}", iat: iat, exp: exp }

      token = JWT.encode(payload, private_key, "ES256", { alg: "ES256", kid: "#{key_id}" })
      puts "Generated MusicKit JWT token #{token}"

      @auth_tokens[:app] = {
        expires_at: DateTime.now + expiration_in_days,
        token: token
      }

      token
    end

    def authenticate_user(token)
      existing = @auth_tokens[:user]

      unless existing.nil? || existing[:expires_at].nil? || existing[:expires_at] < DateTime.now
        puts 'Skipping user authentication...'
        return existing[:token]
      end

      # Generate a new access refresh token,
      # this might require user interaction. Since the
      # user has to authenticate through the browser
      # via Spotify's website, we use a small embedded
      # HTTP server as a 'callback'.

      port = 17997
      server = WEBrick::HTTPServer.new({
        Port: port,
        StartCallback: Proc.new do
          Launchy.open("http://localhost:#{port}/")
        end
      })
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
          "          app: { name: 'Drum', build: '#{VERSION}' }",
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

      trap 'INT' do server.shutdown end

      puts "Launching callback HTTP server on port #{port}, waiting for auth code..."
      server.start

      if user_token.nil?
        raise "Did not get a MusicKit user token."
      end
      puts "Generated MusicKit user token #{user_token}"

      # Cache user token for half an hour (an arbitrary duration)
      expiration_in_seconds = 1800

      @auth_tokens[:user] = {
        expires_at: DateTime.now + (expiration_in_seconds / 86400.0),
        token: user_token
      }

      user_token
    end

    def authenticate
      p8_file = ENV[MUSICKIT_P8_FILE_VAR]
      key_id = ENV[MUSICKIT_KEY_VAR]
      team_id = ENV[MUSICKIT_TEAM_ID_VAR]

      if p8_file.nil? || key_id.nil? || team_id.nil?
        raise "Please specify your MusicKit keys (#{MUSICKIT_P8_FILE_VAR}, #{MUSICKIT_KEY_VAR}, #{MUSICKIT_TEAM_ID_VAR}) in your env vars!"
      end

      token = self.authenticate_app(p8_file, key_id, team_id)
      user_token = self.authenticate_user(token)

      @token = token
      @user_token = user_token
    end

    # API wrapper

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
      json = JSON.parse(response.body)
      puts json
      return json
    end

    def api_library_playlists(offset: 0)
      get_json("/me/library/playlists?limit=#{PLAYLISTS_CHUNK_SIZE}&offset=#{offset}")
    end

    def api_library_playlist_tracks(am_playlist, offset: 0)
      get_json("/me/library/playlists/#{am_playlist['id']}/tracks?limit=#{PLAYLISTS_CHUNK_SIZE}&offset=#{offset}")
    end

    # Download helpers

    def all_am_library_playlists(offset: 0, total: nil)
      unless total != nil && offset >= total
        response = self.api_library_playlists(offset: offset)
        am_playlists = response['data']
        unless am_playlists.empty?
          return am_playlists + self.all_am_library_playlists(offset: offset + PLAYLISTS_CHUNK_SIZE, total: response.dig('meta', 'total'))
        end
      end
      []
    end

    def all_am_library_playlist_tracks(am_playlist, offset: 0, total: nil)
      unless total != nil && offset >= total
        response = self.api_library_playlist_tracks(am_playlist, offset: offset)
        am_tracks = response['data']
        unless am_tracks.empty?
          return am_tracks + self.all_am_library_playlist_tracks(am_playlist, offset: offset + PLAYLISTS_CHUNK_SIZE, total: response.dig('meta', 'total'))
        end
      end
      []
    end

    def from_am_id(am_id)
      unless am_id.nil?
        Digest::SHA1.hexdigest(am_id)
      else
        nil
      end
    end

    def from_am_library_track(am_track, new_playlist)
      am_attributes = am_track['attributes']

      # TODO: Album artwork, etc.
      # TODO: Generate the album/artist IDs from something other than the names
      # TODO: Apple Music-specific metadata (ids)

      new_track = Track.new(
        name: am_attributes['name'],
        duration_ms: am_attributes['durationInMillis']
      )

      album_name = am_attributes['albumName']
      artist_name = am_attributes['artistName']

      new_album = Album.new(
        id: self.from_am_id(album_name),
        name: album_name
      )

      new_artist = Artist.new(
        id: self.from_am_id(artist_name),
        name: artist_name
      )
      new_track.artist_ids = [new_artist.id]

      [new_track, new_artist, new_album]
    end

    def from_am_library_playlist(am_playlist, output: method(:puts))
      am_attributes = am_playlist['attributes']
      new_playlist = Playlist.new(
        name: am_attributes['name'] || '',
        description: am_attributes.dig('description', 'standard'),
        applemusic: PlaylistAppleMusic.new(
          library_id: am_attributes.dig('playParams', 'id'),
          global_id: am_attributes.dig('playParams', 'globalId'),
          public: am_attributes['isPublic'],
          editable: am_attributes['canEdit']
        )
      )

      new_playlist.id = self.from_am_id(am_playlist['id'])

      # TODO: Author information

      begin
        am_tracks = self.all_am_library_playlist_tracks(am_playlist)
        output.call "Got #{am_tracks.length} playlist track(s) for '#{new_playlist.name}'..."
        am_tracks.each do |am_track|
          new_track, new_artist, new_album = self.from_am_library_track(am_track, new_playlist)

          new_playlist.store_track(new_track)
          new_playlist.store_artist(new_artist)
          new_playlist.store_album(new_album)
        end
      rescue RestClient::NotFound
        # Swallow 404s, apparently sometimes there are no tracks associated with a list
        nil
      end

      new_playlist
    end

    # Ref parsing

    def parse_resource_type(raw)
      case raw
      when 'playlist' then :playlist
      when 'album' then :album
      when 'artist' then :artist
      else nil
      end
    end

    def parse_applemusic_link(raw)
      # Parses links like https://music.apple.com/us/playlist/some-name/pl.123456789
      # TODO: Investigate whether such links can always be fetched through the catalog API

      uri = URI(raw)
      unless ['http', 'https'].include?(uri&.scheme) && uri&.host == 'music.apple.com'
        return nil
      end

      parsed_path = uri.path.split('/')
      unless parsed_path.length == 5
        return nil
      end

      storefront = parsed_path[1]
      resource_type = parsed_path[2]
      resource_location = parsed_path[4]

      Ref.new(self.name, resource_type, [storefront, resource_location])
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
        self.parse_applemusic_link(raw_ref.text)
      end
    end

    # Service

    def download(ref)
      self.authenticate

      case ref.resource_type
      when :special
        case ref.resource_location
        when :playlists
          puts 'Querying library playlists...'
          am_playlists = self.all_am_library_playlists.filter { |p| !p.dig('attributes', 'name').nil? }

          puts 'Fetching playlists...'
          bar = ProgressBar.new(am_playlists.length)

          Enumerator.new do |enum|
            am_playlists.each do |am_playlist|
              new_playlist = self.from_am_library_playlist(am_playlist, output: bar.method(:puts))
              bar.increment!
              enum.yield new_playlist
            end
          end
        else raise "Special resource location '#{ref.resource_location}' cannot be downloaded (yet)"
        end
      else raise "Resource type '#{ref.resource_type}' cannot be downloaded (yet)"
      end
    end

    # TODO: Uploading
  end
end
