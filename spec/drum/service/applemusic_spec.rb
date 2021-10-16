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

  after :all do
    FileUtils.remove_dir(@tmpdir)
  end

  before :each do
    def split_endpoint(endpoint)
      endpoint.split(/[\/&]|(?<=[\?\=])/)[1...]
    end

    allow(@service).to receive(:authenticate) do
      # Skipping authentication in test
    end

    allow(@service).to receive(:get_json) do |endpoint|
      # IDs and URLs are made up for testing and do not correspond to any real Apple Music IDs/URLs
      case split_endpoint(endpoint)
      in ['me', 'library', 'playlists?', *]
        {
          'data' => [
            {
              'id' => 'p.abcdefg',
              'type' => 'library-playlists',
              'href' => '/v1/me/library/playlists/p.abcdefg',
              'attributes' => {
                'artwork' => {
                  'url' => 'https://example.com/test-playlist-artwork.jpg'
                },
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
                  'url' => 'https://example.com/platinum-collection-artwork-{w}x{h}.jpg'
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
                  'width' => 64,
                  'height' => 64,
                  'url' => 'https://example.com/elvis-presley-artwork-{w}x{h}.jpg'
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
      in ['catalog', 'de', 'search?', 'term=', term, 'limit=', '1', 'offset=', '0', 'types=', 'songs']
        case term
        when 'Another+One+Bites+The+Dust+Queen'
          {
            'results' => {
              'songs' => {
                'href' => '/v1/catalog/de/search?limit=1&offset=0&term=Another+One+Bites+The+Dust+Queen&types=songs',
                'next' => '/v1/catalog/de/search?offset=1&term=Another+One+Bites+The+Dust+Queen&types=songs',
                'data' => [
                  {
                    'id' => '3531',
                    'type' => 'songs',
                    'href' => '/v1/catalog/de/songs/3531',
                    'attributes' => {
                      'previews' => [
                        {
                          'url' => 'https://example.com/another-one-bites-the-dust.mp3'
                        }
                      ],
                      'artwork' => {
                        'width' => 1500,
                        'height' => 1500,
                        'url' => 'https://example.com/platinum-collection-artwork-{w}x{h}.jpg',
                        'bgColor' => '929196',
                        'textColor1' => '09090a',
                        'textColor2' => '1b1a1c',
                        'textColor3' => '252426',
                        'textColor4' => '323235'
                      },
                      'artistName' => 'Queen',
                      'discNumber' => 1,
                      'genreNames' => [
                        'Rock',
                        'Musik'
                      ],
                      'durationInMillis' => 215336,
                      'releaseDate' => '1980-06-30',
                      'name' => 'Another One Bites the Dust',
                      'isrc' => 'GBUM71029605',
                      'hasLyrics' => true,
                      'albumName' => 'The Platinum Collection',
                      'playParams' => {
                        'id' => '3531',
                        'kind' => 'song'
                      },
                      'trackNumber' => 2,
                      'composerName' => 'John Deacon'
                    }
                  }
                ]
              }
            },
            'meta' => {
              'results' => {
                'order' => [
                  'songs'
                ],
                'rawOrder' => [
                  'songs'
                ]
              }
            }
          }
        when 'Music+John+Miles'
          {
            'results' => {
              'songs' => {
                'href' => '/v1/catalog/de/search?limit=1&offset=0&term=Music+John+Miles&types=songs',
                'next' => '/v1/catalog/de/search?offset=1&term=Music+John+Miles&types=songs',
                'data' => [
                  {
                    'id' => '9588',
                    'type' => 'songs',
                    'href' => '/v1/catalog/de/songs/9588',
                    'attributes' => {
                      'previews' => [
                        {
                          'url' => 'https://example.com/music.mp3'
                        }
                      ],
                      'artwork' => {
                        'width' => 1648,
                        'height' => 1480,
                        'url' => 'https://example.com/music-artwork-{w}x{h}.jpg',
                        'bgColor' => 'a50a13',
                        'textColor1' => 'fffeff',
                        'textColor2' => 'fdcfba',
                        'textColor3' => 'edcdcf',
                        'textColor4' => 'eba899'
                      },
                      'artistName' => 'John Miles',
                      'discNumber' => 1,
                      'genreNames' => [
                        'Rock',
                        'Musik'
                      ],
                      'durationInMillis' => 352733,
                      'releaseDate' => '1998-01-01',
                      'name' => 'Music',
                      'isrc' => 'GBF077620010',
                      'hasLyrics' => true,
                      'albumName' => 'Number Ones - 70s Rock',
                      'playParams' => {
                        'id' => '9588',
                        'kind' => 'song'
                      },
                      'trackNumber' => 15,
                      'composerName' => 'John Miles'
                    }
                  }
                ]
              }
            },
            'meta' => {
              'results' => {
                'order' => [
                  'songs'
                ],
                'rawOrder' => [
                  'songs'
                ]
              }
            }
          }
        else raise "Apple Music search results for term '#{term}' not mocked!"
        end
      else raise "Apple Music API endpoint #{endpoint} not mocked!"
      end
    end

    allow(@service).to receive(:post_json) do |endpoint, json|
      case split_endpoint(endpoint)
      in ['me', 'library', 'playlists']
        am_id = 'p.6811'
        am_attributes = {
          'canEdit' => true,
          'name' => json.dig('attributes', 'name'),
          'hasCatalog' => false,
          'description' => {
            'standard' => json.dig('attributes', 'description')
          },
          'playParams' => {
            'id' => am_id,
            'kind' => 'playlist',
            'isLibrary' => true
          },
          'isPublic' => false
        }

        @created_am_playlist = json
        @created_am_playlist['id'] = am_id
        @created_am_playlist['attributes'].merge!(am_attributes)

        {
          'data' => [
            {
              'id' => am_id,
              'type' => 'library-playlists',
              'href' => "/v1/me/library/playlists/#{am_id}",
              'attributes' => am_attributes
            }
          ]
        }
      end
    end
  end

  describe 'download' do
    it 'should download library playlists correctly' do
      ref = @service.parse_ref(Drum::RawRef.parse('@applemusic/playlists'))
      actual = @service.download(ref).to_a
      expected = [
        Drum::Playlist.new(
          id: '6417b26e1a17b15ecccfc855d3f2a5a926298433',
          name: 'Test 1',
          description: 'Sample description',
          applemusic: Drum::PlaylistAppleMusic.new(
            library_id: 'p.abcdefg',
            global_id: 'pl.hijklmnop',
            public: false,
            editable: true,
            image_url: 'https://example.com/test-playlist-artwork.jpg'
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
              name: 'The Platinum Collection',
              applemusic: Drum::AlbumAppleMusic.new(
                image_url: 'https://example.com/platinum-collection-artwork-512x512.jpg'
              )
            ),
            '8c379b58b4028863b32a84e5affbc1cd0a5f2537' => Drum::Album.new(
              id: '8c379b58b4028863b32a84e5affbc1cd0a5f2537',
              name: 'Elvis Presley',
              applemusic: Drum::AlbumAppleMusic.new(
                image_url: 'https://example.com/elvis-presley-artwork-64x64.jpg'
              )
            )
          },
          tracks: [
            Drum::Track.new(
              name: 'Bohemian Rhapsody',
              album_id: '99905cf4ee43a16ac92086c9c3a396f997088c7f',
              artist_ids: [
                '6911adcc6c625bb5c52c5093aa8cdb0545ca63d4'
              ],
              genres: [
                'Rock'
              ],
              duration_ms: 355145,
              released_at: DateTime.parse('1975-10-31'),
              applemusic: Drum::TrackAppleMusic.new(
                library_id: 'i.qrst',
                catalog_id: '12345'
              )
            ),
            Drum::Track.new(
              name: 'Blue Suede Shoes',
              album_id: '8c379b58b4028863b32a84e5affbc1cd0a5f2537',
              artist_ids: [
                '8c379b58b4028863b32a84e5affbc1cd0a5f2537'
              ],
              genres: [
                'Rock'
              ],
              duration_ms: 122133,
              released_at: DateTime.parse('1956-03-23'),
              applemusic: Drum::TrackAppleMusic.new(
                library_id: 'i.uvwx',
                catalog_id: '67890'
              )
            )
          ]
        )
      ]
      expect(actual).to eq expected
    end
  end

  describe 'upload' do
    it 'should upload library playlists correctly' do
      @service.upload_playlist(Drum::Playlist.new(
        id: '0',
        name: 'Example',
        artists: {
          'queen' => Drum::Artist.new(
            id: 'queen',
            name: 'Queen'
          ),
          'john-miles' => Drum::Artist.new(
            id: 'john-miles',
            name: 'John Miles'
          )
        },
        tracks: [
          Drum::Track.new(
            name: 'Music',
            artist_ids: [
              'john-miles'
            ]
          ),
          Drum::Track.new(
            name: 'Another One Bites The Dust',
            artist_ids: [
              'queen'
            ]
          )
        ]
      ))
      expect(@created_am_playlist).to eq({
        'id' => 'p.6811',
        'attributes' => {
          'canEdit' => true,
          'name' => 'Example',
          'hasCatalog' => false,
          'description' => {
            'standard' => ''
          },
          'playParams' => {
            'id' => 'p.6811',
            'kind' => 'playlist',
            'isLibrary' => true
          },
          'isPublic' => false
        },
        'relationships' => {
          'tracks' => {
            'data' => [
              {
                'id' => '9588',
                'type' => 'songs'
              },
              {
                'id' => '3531',
                'type' => 'songs'
              }
            ]
          }
        }
      })
    end
  end

  describe Drum::AppleMusicService::CachedFolderNode do
    before :all do
      @c = Drum::AppleMusicService::CachedFolderNode.new(
        name: 'c',
        am_library_id: 'id.c'
      )
      @d = Drum::AppleMusicService::CachedFolderNode.new(
        name: 'd',
        am_library_id: 'id.d'
      )
      @b = Drum::AppleMusicService::CachedFolderNode.new(
        name: 'b',
        am_library_id: 'id.b',
        children: {'c' => @c}
      )
      @a = Drum::AppleMusicService::CachedFolderNode.new(
        name: 'a',
        am_library_id: 'id.a',
        children: {
          'b' => @b,
          'd' => @d
        }
      )
    end

    describe 'lookup' do
      it 'should find nodes in a nested tree' do
        expect(@a.lookup([])).to be(@a)
        expect(@a.lookup(['b'])).to be(@b)
        expect(@a.lookup(['d'])).to be(@d)
        expect(@a.lookup(['c'])).to be_nil
        expect(@a.lookup(['b', 'c'])).to be(@c)
      end
    end

    describe 'by_am_library_ids' do
      it 'should generate a flat id to node hash' do
        expect(@a.by_am_library_ids).to eq({
          'id.a' => @a,
          'id.b' => @b,
          'id.c' => @c,
          'id.d' => @d
        })
      end
    end

    describe 'parent' do
      it 'should find the correct parents' do
        # We cannot compare for object identity with 'be' here
        # since the tree is using WeakRef wrappers internally.
        expect(@a.parent).to be_nil
        expect(@b.parent).to eq(@a)
        expect(@d.parent).to eq(@a)
        expect(@c.parent).to eq(@b)
      end
    end
  end
end
