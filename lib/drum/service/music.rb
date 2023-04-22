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

    # Service

    def download(ref)
      self.require_rb_scpt

      raise 'Downloading is not implemented yet'
    end

    def upload(ref, playlists)
      self.require_rb_scpt

      unless ref.resource_type == :special && ref.resource_location == :playlists
        raise "Cannot upload to anything other than @#{self.name}/playlists yet!"
      end
      
      # TODO
      raise 'Uploading is not implemented yet'
    end
  end
end
