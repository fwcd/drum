# Drum Playlist Format

Drum uses a YAML-based format to represent playlists. This makes it easy to back them up, check them into version control and use them in other tools, among others. There are two basic flavors of playlists, though both share the same rough structure:

* **Regular playlists**, which are a simple list of songs
* **Smart playlists**, which additionally include a list of filtering rules

A playlist is 'smart' if and only if it contains `filter`s.

> Note that by default, Drum will only allow copying smart playlists to destinations that support smart playlists (currently just local files). With the `-x`/`--execute` flag, however, the smart playlist will be converted into a regular playlist during the copying, thereby allowing all destinations that support regular playlists.

## Specification

### Playlist

The top-level object in a playlist file.

```yaml
name: string
description: string?
author: string? (references User.id)
users: User[]?
artist: Artist[]?
tracks: Track[]?
```

### User

```yaml
id: string
display_name: string?
spotify: SpotifyRef?
```

### Artist

```yaml
id: string
name: String
spotify: SpotifyRef?
```

### Track

```yaml
name: string
artist: string (references Artist.id)
duration_ms: number?
explicit: boolean?
isrc: string?
spotify: SpotifyRef?
```

### SpotifyRef

```yaml
id: string
uri: string
web_url: string
```
