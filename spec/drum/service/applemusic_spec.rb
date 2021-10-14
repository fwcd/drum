require 'drum/service/applemusic'
require 'drum/model/playlist'
require 'drum/model/raw_ref'
require 'pathname'
require 'tmpdir'

describe Drum::AppleMusicService do
  before :all do
    @tmpdir = Pathname.new(Dir.mktmpdir('drum-applemusic-spec'))
    @service = Drum::AppleMusicService.new(@tmpdir)
  end

  before :each do
    allow(@service).to receive(:authenticate) do
      puts 'Skipping authentication in test'
    end

    allow(@service).to receive(:get_json) do |endpoint|
      case endpoint.split(/[\/&]|(?<=[\?\=])/)[1...]
      in ['me', 'library', 'playlists?', *]
        {
          'data' => [
            {
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
            }
          ],
          'meta' => {
            'total' => 1
          }
        }
      in ['me', 'library', 'playlists', am_id, 'tracks?', *]
        {
          'data' => [],
          'meta' => {
            'total' => 0
          }
        }
      else raise "Apple Music API endpoint #{endpoint} not mocked!"
      end
    end
  end

  after :all do
    FileUtils.remove_dir(@tmpdir)
  end

  describe 'download' do
    it 'should download library playlists correctly' do
      ref = @service.parse_ref(Drum::RawRef.parse('@applemusic/playlists'))
      actual = @service.download(ref).to_a
      expected = [
        Drum::Playlist.new(
          id: '1182bfec694d614c35cb79702e435cc193029e08',
          name: 'Test 1',
          description: 'Sample description',
          applemusic: Drum::PlaylistAppleMusic.new(
            library_id: 'p.abcdefg',
            global_id: 'pl.hijklmnop',
            public: false,
            editable: true
          )
        )
      ]
      expect(actual).to eq expected
    end
  end
end
