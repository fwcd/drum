# Drum

A small tool for syncing your playlists across music streaming services and with your local library.

## To Do

- [ ] CLI with commands (`pull`, `push`, `sync`, ...)
- [ ] Push/pull for popular streaming services (Spotify, Apple Music, ...) and local library
    - [ ] This involves matching songs across services, possibly though heuristics
- [ ] Import/export of common playlist formats (Drum's own `json` format, `m3u`, ...)
- [ ] Playlist folders
- [ ] Smart playlists (making rules, then e.g. syncing them to streaming services, even if these have no notion of 'smart' playlists)

## Development

After checking out the repo, run `bin/setup` (or `bundle install`) to install dependencies. If you use macOS and the installation of the SQLite3 gem fails, try

```
sudo gem install sqlite3 -- --with-sqlite3-lib=/usr/lib
```

To run the application, run `bundle exec bin/drum`. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fwcd/drum.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
