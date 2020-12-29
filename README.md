# Drum

A small tool for syncing your playlists across music streaming services and with your local library.

## To Do

- [ ] CLI with commands (`pull`, `push`, `sync`, ...)
- [ ] Push/pull for popular streaming services (Spotify, Apple Music, ...) and local library
    - [ ] This involves matching songs across services, possibly though heuristics
- [ ] Import/export of common playlist formats (Drum's own `json` format, `m3u`, ...)
- [ ] Playlist folders
- [ ] Smart playlists (making rules, then e.g. syncing them to streaming services, even if these have no notion of 'smart' playlists)
- [ ] Store metadata like BPM, key, time signature, etc

## Development

After checking out the repo, run `bin/setup` (or `bundle install`) to install dependencies. If you use macOS and the installation of the SQLite3 gem fails, try

```
sudo gem install sqlite3 -- --with-sqlite3-lib=/usr/lib
```

To run the application, run `bundle exec bin/drum`. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To use the service integrations, e.g. with Spotify, set the following environment variables:

```
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...
```

The client ID and secret can be obtained by creating a Spotify application in the [developer dashboard](https://developer.spotify.com/dashboard/applications). After adding the application, make sure to whitelist the following redirect URI (required for user authentication):

```
http://localhost:17998/callback
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fwcd/drum.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
