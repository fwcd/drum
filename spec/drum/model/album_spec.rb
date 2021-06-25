require 'drum/model/album'

describe Drum::Album do
  describe 'Drum::deserialize' do
    it 'should deserialize correctly' do
      expect(Drum::Album.deserialize({
        'id' => '0',
        'name' => 'Abbey Road',
        'artist_ids' => ['1'],
        'spotify' => {
          'id' => '0ETFjACtuP2ADo6LFhL6HN',
          'image_url' => 'https://i.scdn.co/image/ab67616d00001e02dc30583ba717007b00cceb25'
        }
      })).to eq Drum::Album.new(
        id: '0',
        name: 'Abbey Road',
        artist_ids: ['1'],
        spotify: Drum::AlbumSpotify.new(
          id: '0ETFjACtuP2ADo6LFhL6HN',
          image_url: 'https://i.scdn.co/image/ab67616d00001e02dc30583ba717007b00cceb25'
        )
      )
    end
  end
end
