require 'drum/model/playlist'
require 'drum/model/ref'
require 'pathname'
require 'yaml'

module Drum
  # A service that reads/writes playlists to/from YAML files.
  class FileService < Service
    def name
      'file'
    end

    def supports_source_mutations
      true
    end

    def parse_ref(raw_ref)
      unless raw_ref.is_token
        path = Pathname.new(raw_ref.text)
        Ref.new(self.name, :any, path)
      else
        nil
      end
    end

    def remove(playlist_ref)
      path = playlist_ref.resource_location
      if path.directory?
        raise 'Removing directories is not supported!'
      end
      puts "Removing #{path}..."
      path.delete
    end

    def download(playlist_ref)
      path = playlist_ref.resource_location
      paths = if path.directory?
        path.children
      else
        [path]
      end
      paths.map { |p| Playlist.deserialize(YAML.load(p.read)) }
    end

    def upload(playlist_ref, playlists)
      path = playlist_ref.resource_location
      playlists.each do |playlist|
        yaml = playlist.serialize.to_yaml

        if path.directory?
          playlist_path = lambda do |length|
            path.join("#{playlist.name.kebabcase}-#{playlist.id[...length]}.yaml")
          end

          length = 6
          while playlist_path[length].exist? && Playlist.deserialize(YAML.load(playlist_path[length].read)).id != playlist.id
            length += 1
          end

          playlist_path[length].write(yaml)
        else
          path.write(yaml)
        end
      end
    end
  end
end
