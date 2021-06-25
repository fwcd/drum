require 'drum/model/playlist'
require 'drum/model/artist'
require 'drum/model/track'

describe Drum::Playlist do
  describe 'Playlist::deserialize' do
    it 'should deserialize correctly' do
      expect(Drum::Playlist.deserialize({
        'name' => 'My Playlist',
        'description' => 'Lots of great songs',
        'artists' => [
          { 'id' => '0', 'name' => 'Queen' },
          { 'id' => '1', 'name' => 'The Beatles' }
        ],
        'tracks' => [
          { 'name' => 'Bohemian Rhapsody', 'artist_ids' => ['0'] },
          { 'name' => 'Let it be', 'artist_ids' => ['1'] }
        ]
      })).to eq Drum::Playlist.new(
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
      )
    end
  end
end
