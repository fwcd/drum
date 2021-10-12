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

    def parse_ref(raw_ref)
      # TODO
      nil
    end

    def download(ref)
      # TODO
      []
    end
  end
end
