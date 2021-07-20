module Drum
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
          name: 'My Playlist',
          description: 'Lots of great songs',
          artists: [
            Drum::Artist.new(id: '0', name: 'Queen'),
            Drum::Artist.new(id: '1', name: 'The Beatles')
          ],
          tracks: [
            Drum::Track.new(name: 'Bohemian Rhapsody', artist_ids: ['0']),
            Drum::Track.new(name: 'Let it be', artist_ids: ['1'])
          ]
        )]
      else
        []
      end
    end
  end
end
