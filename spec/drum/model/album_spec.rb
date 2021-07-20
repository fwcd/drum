require 'drum/model/album'

describe Drum::Album do
  describe 'Album::deserialize' do
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

  describe 'Album::serialize' do
    it 'should serialize correctly' do
      expect(Drum::Album.new(
        id: '1',
        name: '÷',
        spotify: Drum::AlbumSpotify.new(
          id: '3T4tUhGYeRNVUGevb0wThu',
          image_url: 'https://i.scdn.co/image/ab67616d00001e02ba5db46f4b838ef6027e6f96'
        )
      ).serialize).to eq({
        'id' => '1',
        'name' => '÷',
        'artist_ids' => nil,
        'spotify' => {
          'id' => '3T4tUhGYeRNVUGevb0wThu',
          'image_url' => 'https://i.scdn.co/image/ab67616d00001e02ba5db46f4b838ef6027e6f96'
        }
      })
    end
  end
end
