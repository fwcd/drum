# Drum

A small CLI tool for syncing your playlists across music streaming services and with your local library.

![Icon](artwork/icon128.png)

Drum supports a range of commands:

* **Music streaming services**
    * `drum preview [service]` outputs personal playlists from the given service that are available for `pull`
    * `drum pull [service]` downloads all personal playlists and the user's stored tracks from the given service
    * `drum push [service] -p [playlist id]` uploads a single playlist from the local library to the given service
* **Local library management**
    * `drum playlists` outputs the locally stored playlists
    * `drum tracks -p [playlist id]` outputs the tracks in a locally stored playlist

Currently, the following music streaming services are supported:

* `spotify`
* `applemusic` (partially, only `pull`)

> Note that the tool only processes metadata, not the actual audio files.

## Development

After checking out the repo, run `bin/setup` (or `bundle install`) to install dependencies. If you use macOS and the installation of the SQLite3 gem fails, try

```
sudo gem install sqlite3 -- --with-sqlite3-lib=/usr/lib
```

To run the application, run `bundle exec bin/drum`. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

> Note that you may need to run `bundle exec ruby bin/drum` on Windows

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
