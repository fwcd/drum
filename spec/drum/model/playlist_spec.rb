require 'drum/model/playlist'
require 'drum/model/artist'
require 'drum/model/track'

describe Drum::Playlist do
  describe 'deserialize' do
    it 'should deserialize correctly' do
      expect(Drum::Playlist.deserialize({
        'id' => '9',
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
        id: '9',
        name: 'My Playlist',
        description: 'Lots of great songs',
        artists: {
          '0' => Drum::Artist.new(id: '0', name: 'Queen'),
          '1' => Drum::Artist.new(id: '1', name: 'The Beatles')
        },
        tracks: [
          Drum::Track.new(name: 'Bohemian Rhapsody', artist_ids: ['0']),
          Drum::Track.new(name: 'Let it be', artist_ids: ['1'])
        ]
      )
    end
  end

  describe 'Playlist::serialize' do
    it 'should serialize correctly' do
      expect(Drum::Playlist.new(
        id: '7',
        name: 'My Playlist 2',
        description: 'More great songs',
        artists: {
          '0' => Drum::Artist.new(id: '0', name: 'Elvis Presley')
        },
        tracks: [
          Drum::Track.new(name: 'Jailhouse Rock', artist_ids: ['0'])
        ]
      ).serialize).to eq({
        'id' => '7',
        'name' => 'My Playlist 2',
        'description' => 'More great songs',
        'artists' => [
          { 'id' => '0', 'name' => 'Elvis Presley' }
        ],
        'tracks' => [
          { 'name' => 'Jailhouse Rock', 'artist_ids' => ['0'] }
        ]
      })
    end
  end
end
