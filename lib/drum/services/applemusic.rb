require 'drum/services/service'
require 'jwt'

module Drum
  class AppleMusicService < Service
    NAME = 'Apple Music'

    def initialize(db)
      @db = db
      service = db[:services].where(:name => NAME).first
      if service.nil?
        @service_id = db[:services].insert(:name => NAME)
      else
        @service_id = service[:id]
      end
    end

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

    def authenticate
      p8_file = ENV['MUSICKIT_KEY_P8_FILE_PATH']
      key_id = ENV['MUSICKIT_KEY_ID']
      team_id = ENV['MUSICKIT_TEAM_ID']

      if p8_file.nil? || key_id.nil? || team_id.nil?
        raise 'Please specify your MusicKit keys in your env vars!'
      end

      @token = self.authenticate_app(p8_file, key_id, team_id)
      puts "Generated MusicKit JWT token #{@token}"
    end

    def preview
      self.authenticate

      # TODO
    end
  end
end
