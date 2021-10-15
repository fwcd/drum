require 'drum/model/playlist'
require 'drum/model/ref'
require 'drum/service/service'
require 'drum/utils/log'
require 'yaml'

module Drum
  # A service that reads from stdin and writes to stdout.
  class StdioService < Service
    include Log

    def name
      'stdio'
    end

    def parse_ref(raw_ref)
      if raw_ref.is_token
        location = case raw_ref.text
        when 'stdout' then :stdout
        when 'stdin' then :stdin
        else return nil
        end
        Ref.new(self.name, :any, [location])
      elsif raw_ref.text == '-'
        Ref.new(self.name, :any, [:stdin, :stdout])
      else
        nil
      end
    end

    def download(playlist_ref)
      if playlist_ref.resource_location.include?(:stdin)
        # TODO: Support multiple, --- delimited playlists?
        [Playlist.deserialize(YAML.load(STDIN.read))]
      else
        []
      end
    end

    def upload(playlist_ref, playlists)
      if playlist_ref.resource_location.include?(:stdout)
        playlists.each do |playlist|
          log.all playlist.serialize.to_yaml
        end
        nil
      else
        raise 'Cannot upload to somewhere other than stdout!'
      end
    end
  end
end
