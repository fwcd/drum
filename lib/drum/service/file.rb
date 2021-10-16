require 'drum/model/playlist'
require 'drum/model/ref'
require 'drum/service/service'
require 'drum/utils/log'
require 'pathname'
require 'uri'
require 'yaml'

module Drum
  # A service that reads/writes playlists to/from YAML files.
  class FileService < Service
    include Log

    def name
      'file'
    end

    def parse_ref(raw_ref)
      if raw_ref.is_token
        return nil
      end

      raw_path = if raw_ref.text.start_with?('file:')
        URI(raw_ref.text).path
      else
        raw_ref.text
      end

      path = Pathname.new(raw_path)
      Ref.new(self.name, :any, path)
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
      base_path = playlist_ref.resource_location

      if base_path.directory?
        Dir.glob("#{base_path}/**/*.{yaml,yml}").map do |p|
          path = Pathname.new(p)
          playlist = Playlist.deserialize(YAML.load(path.read))
          playlist.path = if path.parent == base_path
            []
          else
            path.parent.relative_path_from(base_path).each_filename.to_a
          end
          playlist
        end
      else
        [Playlist.deserialize(YAML.load(base_path.read))]
      end
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
            path = path / playlist.path.map { |n| Pathname.new(n) }.reduce(:/)
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
