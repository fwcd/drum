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
          'data' => [
            {
              'id' => 'i.qrst',
              'type' => 'library-songs',
              'href' => '/v1/me/library/songs/i.qrst',
              'attributes' => {
                'artwork' => {
                  'width' => 1200,
                  'height' => 1200,
                  'url' => 'https://example.com/artwork.jpg'
                },
                'artistName' => 'Queen',
                'discNumber' => 1,
                'genreNames' => [
                  'Rock'
                ],
                'durationInMillis' => 355145,
                'releaseDate' => '1975-10-31',
                'name' => 'Bohemian Rhapsody',
                'hasLyrics' => true,
                'albumName' => 'The Platinum Collection',
                'playParams' => {
                  'id' => 'i.qrst',
                  'kind' => 'song',
                  'isLibrary' => true,
                  'reporting' => true,
                  'catalogId' => '12345'
                },
                'trackNumber' => 1
              }
            },
            {
              'id' => 'i.uvwx',
              'type' => 'library-songs',
              'href' => '/v1/me/library/songs/i.uvwx',
              'attributes' => {
                'artwork' => {
                  'width' => 1200,
                  'height' => 1200,
                  'url' => 'https://example.com/artwork.jpg'
                },
                'artistName' => 'Elvis Presley',
                'discNumber' => 1,
                'genreNames' => [
                  'Rock'
                ],
                'durationInMillis' => 122133,
                'releaseDate' => '1956-03-23',
                'name' => 'Blue Suede Shoes',
                'hasLyrics' => true,
                'albumName' => 'Elvis Presley',
                'playParams' => {
                  'id' => 'i.uvwx',
                  'kind' => 'song',
                  'isLibrary' => true,
                  'reporting' => true,
                  'catalogId' => '67890'
                },
                'trackNumber' => 1
              }
            }
          ],
          'meta' => {
            'total' => 2
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
          ),
          artists: {
            '6911adcc6c625bb5c52c5093aa8cdb0545ca63d4' => Drum::Artist.new(
              id: '6911adcc6c625bb5c52c5093aa8cdb0545ca63d4',
              name: 'Queen'
            ),
            '8c379b58b4028863b32a84e5affbc1cd0a5f2537' => Drum::Artist.new(
              id: '8c379b58b4028863b32a84e5affbc1cd0a5f2537',
              name: 'Elvis Presley'
            )
          },
          albums: {
            '99905cf4ee43a16ac92086c9c3a396f997088c7f' => Drum::Album.new(
              id: '99905cf4ee43a16ac92086c9c3a396f997088c7f',
              name: 'The Platinum Collection'
            ),
            '8c379b58b4028863b32a84e5affbc1cd0a5f2537' => Drum::Album.new(
              id: '8c379b58b4028863b32a84e5affbc1cd0a5f2537',
              name: 'Elvis Presley'
            )
          },
          tracks: [
            Drum::Track.new(
              name: 'Bohemian Rhapsody',
              artist_ids: [
                '6911adcc6c625bb5c52c5093aa8cdb0545ca63d4'
              ],
              duration_ms: 355145
            ),
            Drum::Track.new(
              name: 'Blue Suede Shoes',
              artist_ids: [
                '8c379b58b4028863b32a84e5affbc1cd0a5f2537'
              ],
              duration_ms: 122133
            )
          ]
        )
      ]
      expect(actual).to eq expected
    end
  end
end
