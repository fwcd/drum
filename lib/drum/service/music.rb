require 'drum/model/album'
require 'drum/model/artist'
require 'drum/model/ref'
require 'drum/model/playlist'
require 'drum/model/track'
require 'drum/service/service'
require 'drum/utils/log'

module Drum
  # A service that uses AppleScript to interact with the local Apple Music (Music.app) library.
  #
  # Useful resources:
  # - https://github.com/BrendanThompson/rb-scpt/tree/develop/sample
  # - https://stackoverflow.com/questions/12964766/create-playlist-in-itunes-with-python-and-scripting-bridge
  # - https://dougscripts.com/itunes/itinfo/info01.php
  # - https://dougscripts.com/itunes/itinfo/info02.php
  # - https://dougscripts.com/itunes/itinfo/info03.php
  # - https://github.com/sorah/jockey/blob/master/add.rb
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

    def to_track_proxy(library_proxy, playlist, track)
      # Get track metadata
      name = track.name
      artists = track.artist_ids.map { |id| playlist.artists[id].name }

      # Match the track with a track in the local library
      # TODO: Don't require exact 100% matches
      name_query = Appscript.its.name.eq(name)
      artists_query = artists
        .map { |a| Appscript.its.artist.contains(a) }
        .reduce { |q1, q2| q1.or(q2) }
      query = name_query.and(artists_query)

      # Find a matching track in the track
      # TODO: Instead of choosing the first, prefer iTunes-matched/higher bitrate ones etc.
      track_proxy = library_proxy.tracks[query].get.first

      if track_proxy.nil?
        log.warn "No match found for '#{track.name}' by '#{artists.first}'"
      else
        log.info "Matched '#{track.name}' with '#{track_proxy.name.get}' by '#{track_proxy.artist.get}'"
      end
      track_proxy
    end

    def upload_playlist(library_proxy, playlist)
      playlist_proxy = library_proxy.make(new: :playlist, with_properties: {
        name: playlist.name,
        description: playlist.description,
      }.compact)
      
      playlist.tracks.each do |track|
        track_proxy = self.to_track_proxy(library_proxy, playlist, track)
        unless track_proxy.nil?
          track_proxy.duplicate(to: playlist_proxy)
        end
      end
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
