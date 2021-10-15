require 'drum/model/playlist'
require 'drum/model/ref'
require 'drum/service/service'
require 'drum/utils/log'
require 'pathname'
require 'yaml'

module Drum
  # A service that reads/writes playlists to/from YAML files.
  class FileService < Service
    include Log

    def name
      'file'
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
      log.info "Removing #{path}..."
      path.delete
    end

    def download(playlist_ref)
      path = playlist_ref.resource_location
      paths = if path.directory?
        path.children.filter { |p| !p.directory? && ['.yml', '.yaml'].include?(p.extname) }
      else
        [path]
      end
      paths.map { |p| Playlist.deserialize(YAML.load(p.read)) }
    end

    def upload(playlist_ref, playlists)
      base_path = playlist_ref.resource_location

      playlists.each do |playlist|
        path = base_path
        dict = playlist.serialize

        # Strip path from serialized playlist
        dict.delete('path')

        if !path.exist? || path.directory?
          unless playlist.path.empty?
            path = path / playlist.path.map { |n| Pathname.new(n.kebabcase) }.reduce(:/)
          end

          playlist_path = lambda do |length|
            path / "#{playlist.name.kebabcase}-#{playlist.id[...length]}.yaml"
          end

          length = 6
          while playlist_path[length].exist? && Playlist.deserialize(YAML.load(playlist_path[length].read)).id != playlist.id
            length += 1
          end

          path = playlist_path[length]
        end

        path.parent.mkpath
        path.write(dict.to_yaml)
      end
    end
  end
end
