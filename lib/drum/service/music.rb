require 'drum/model/album'
require 'drum/model/artist'
require 'drum/model/ref'
require 'drum/model/playlist'
require 'drum/model/track'
require 'drum/service/service'
require 'drum/utils/log'

module Drum
  # A service that uses AppleScript to interact with the local Apple Music (Music.app) library.
  class MusicService < Service
    include Log

    def name
      'music'
    end

    def require_rb_scpt
      begin
        require 'rb-scpt'
      rescue LoadError
        raise "Using the local Apple Music importer requires the 'rb-scpt' gem (which requires macOS)"
      end
    end

    def get_library_proxy
      self.require_rb_scpt
      music = Appscript.app('Music')
      source = music.sources[1]
      unless source.kind.get == :library
        raise 'Could not get music library source'
      end
      return source
    end

    # Ref parsing

    def parse_ref(raw_ref)
      if raw_ref.is_token
        location = case raw_ref.text
        when "#{self.name}/playlists" then :playlists
        else return nil
        end
        Ref.new(self.name, :special, location)
      else
        nil
      end
    end

    # Upload helpers

    def upload_playlist(library_proxy, playlist)
      library_proxy.make(new: :playlist, with_properties: {
        name: playlist.name,
        description: playlist.description,
      })
      # TODO: Add tracks
    end

    # Service

    def download(ref)
      raise 'Downloading is not implemented yet'
    end

    def upload(ref, playlists)
      library_proxy = self.get_library_proxy

      unless ref.resource_type == :special && ref.resource_location == :playlists
        raise "Cannot upload to anything other than @#{self.name}/playlists yet!"
      end
      
      playlists.each do |playlist|
        self.upload_playlist(library_proxy, playlist)
      end
    end
  end
end
