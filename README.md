# Drum

A small tool for syncing your playlists across music streaming services and with your local library.

![Icon](artwork/icon128.png)

## Development

After checking out the repo, run `bin/setup` (or `bundle install`) to install dependencies. If you use macOS and the installation of the SQLite3 gem fails, try

```
sudo gem install sqlite3 -- --with-sqlite3-lib=/usr/lib
```

To run the application, run `bundle exec bin/drum`. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

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
MUSICKIT_PRIVATE_KEY_FILE_PATH=...
```

This private key can be obtained as described [here](https://help.apple.com/developer-account/#/devce5522674) or [here](https://developer.apple.com/documentation/applemusicapi/getting_keys_and_creating_tokens) (requires an Apple Developer Program membership).

## Limitations

* The Spotify API [does not](https://developer.spotify.com/documentation/general/guides/working-with-playlists/#folders) provide a way to access folders currently

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fwcd/drum.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
