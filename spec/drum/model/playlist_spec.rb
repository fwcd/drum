require 'drum/model/playlist.rb'
require 'drum/model/artist.rb'
require 'drum/model/track.rb'

module Drum
  describe Playlist do
    describe 'Playlist::deserialize' do
      it 'should deserialize correctly' do
        expect(Playlist.deserialize({
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
        })).to eq Playlist.new(
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
        )
      end
    end
  end
end
