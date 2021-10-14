require 'drum/service/applemusic'
require 'drum/model/playlist'
require 'pathname'
require 'tmpdir'

describe Drum::AppleMusicService do
  before :all do
    @tmpdir = Pathname.new(Dir.mktmpdir('drum-applemusic-spec'))
    @service = Drum::AppleMusicService.new(@tmpdir)
  end

  after :all do
    FileUtils.remove_dir(@tmpdir)
  end

  describe 'from_am_library_playlist' do
    it 'should be converted correctly' do
      expect(@service.from_am_library_playlist({
        'id' => 'p.abcdefg',
        'type' => 'library-playlists',
        'href' => '/v1/me/library/playlists/p.abcdefg',
        'attributes' => {
          'canEdit' => true,
          'dateAdded' => '2021-01-22T13:02:16Z',
          'isPublic' => false,
          'name' => 'Test 1',
          'playParams' => {
            'id' => 'p.abcdefg',
            'kind' => 'playlist',
            'isLibrary' => true,
            'globalId' => 'pl.hijklmnop'
          },
          'hasCatalog' => true,
          'description' => {
            'standard' => 'Sample description'
          }
        }
      })).to eq Drum::Playlist.new(
        name: 'Test 1',
        description: 'Sample description',
        applemusic: Drum::PlaylistAppleMusic(
          library_id: 'p.abcdefg',
          global_id: 'pl.hijklmnop',
          public: false
        )
      )
    end
  end
end
