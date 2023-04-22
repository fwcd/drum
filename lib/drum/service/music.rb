require 'drum/model/album'
require 'drum/model/artist'
require 'drum/model/ref'
require 'drum/model/playlist'
require 'drum/model/track'
require 'drum/service/service'
require 'drum/utils/log'
require 'rb-scpt'

module Drum
  # A service that uses AppleScript to interact with the local Apple Music (Music.app) library.
  class MusicService < Service
    include Log

    def name
      'music'
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

    def download(playlist_ref)
      raise 'Downloading is not implemented yet'
    end

    def upload(playlist_ref, playlists)
      unless ref.resource_type == :special && ref.resource_location == :playlists
        raise "Cannot upload to anything other than @#{self.name}/playlists yet!"
      end
      
      # TODO
      raise 'Uploading is not implemented yet'
    end
  end
end
