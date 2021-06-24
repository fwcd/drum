# Drum

A small tool for copying your playlists across music streaming services. Think `rsync`, but for playlists.

![Icon](artwork/icon128.png)

## Usage

The basic usage pattern is always `drum [source] [destination]` where `source` and `destination` may be any of the following:

* A file or folder, e.g. `.`, `some/folder`, `some-file.yaml`
* A URI, e.g. `https://open.spotify.com/playlist/123456`, `spotify:playlist:123456`, `file:///path/to/list.yaml`
* A special token, e.g. `@spotify-library`, `@spotify-liked-songs`

> Note that if the source is folder-like, i.e. includes multiple playlists, the destination has to be folder-like too.

### Examples

**Download a playlist from Spotify.**

* `drum https://open.spotify.com/playlist/123456 my-fancy-list.yaml`
* `drum spotify:playlist:123456 my-fancy-list.yaml`
* `drum spotify:playlist:123456 some/folder`

**Download your liked songs playlist from Spotify.**

* `drum @spotify-liked-songs liked-songs.yaml`

**Download all playlists from your Spotify library.**

* `drum https://open.spotify.com/library .`
* `drum @spotify-library .`

**Upload a playlist to Spotify.**

* `drum my-fancy-list.yaml @spotify-library`

## Supported Services

Currently, the following music streaming services are supported:

* `spotify`
* `applemusic` (partially, only `pull`)

> Note that the tool only processes metadata, not the actual audio files.

## Development

After checking out the repo, run `bin/setup` (or `bundle install`) to install dependencies.

To run the application, run `bundle exec bin/drum`. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

> Note that you may need to run `bundle exec ruby bin/drum` on Windows

To package the application into a gem, run `bundle exec rake build`. The built gem should then be located in `pkg`.

To generate the documentation, run `bundle exec rake yard`.

### Spotify

To use the service integration with Spotify, set the following environment variables:

```
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...
```

The client ID and secret can be obtained by creating a Spotify application in the [developer dashboard](https://developer.spotify.com/dashboard/applications). After adding the application, make sure to whitelist the following redirect URI (required for user authentication):

```
http://localhost:17998/callback
```

### Apple Music

To use the service integration with Apple Music, set the following environment variables:

```
MUSICKIT_KEY_P8_FILE_PATH=...
MUSICKIT_KEY_ID=...
MUSICKIT_TEAM_ID=...
```

This (private) p8 key can be obtained as described [here](https://help.apple.com/developer-account/#/devce5522674) or [here](https://developer.apple.com/documentation/applemusicapi/getting_keys_and_creating_tokens) (requires an Apple Developer Program membership).

## Limitations

* Neither the [Spotify API](https://developer.spotify.com/documentation/general/guides/working-with-playlists/#folders) nor the [Apple Music API](https://github.com/Musish/Musish/issues/189#issuecomment-455749901) provide a way to access folders currently

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fwcd/drum.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
