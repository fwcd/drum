require 'drum/model/artist'
require 'drum/model/ref'
require 'drum/model/playlist'
require 'drum/model/track'
require 'drum/service/service'

module Drum
  # A service that provides a mock playlist for ease of manual testing.
  class MockService < Service
    def name
      'mock'
    end

    def parse_ref(raw_ref)
      if raw_ref.is_token && raw_ref.text == 'mock'
        Ref.new(self.name, :playlist, '')
      else
        nil
      end
    end

    def download(playlist_ref)
      if playlist_ref.resource_type == :playlist
        [Playlist.new(
          id: '95d5e24cde85a09ce2ac0ae381179dabacee0202',
          name: 'My Playlist',
          description: 'Lots of great songs',
          artists: [
            Artist.new(id: '0', name: 'Queen'),
            Artist.new(id: '1', name: 'The Beatles')
          ],
          tracks: [
            Track.new(name: 'Bohemian Rhapsody', artist_ids: ['0']),
            Track.new(name: 'Let it be', artist_ids: ['1'])
          ]
        )]
      else
        []
      end
    end
  end
end
