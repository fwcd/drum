require 'drum/model/playlist'
require 'drum/model/ref'
require 'yaml'

module Drum
  class StdioService < Service
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
        Ref.new(self.name, :any, location)
      else
        nil
      end
    end

    def download(playlist_ref)
      if playlist_ref.resource_location == :stdin
        # TODO: Support multiple, --- delimited playlists?
        [Playlist.deserialize(YAML.load(STDIN.read))]
      else
        []
      end
    end

    def upload(playlist_ref, playlists)
      if playlist_ref.resource_location == :stdout
        playlists.each do |playlist|
          puts playlist.serialize.to_yaml
        end
      else
        raise 'Cannot upload to somewhere other than stdout!'
      end
    end
  end
end
