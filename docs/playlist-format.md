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
author_id: string? (references User.id)
users: User[]?
artists: Artist[]?
albums: Album[]?
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
name: string
spotify: SpotifyRef?
```

### Album

```yaml
id: string
name: string
artist_ids: string[] (references Artist.id)
spotify: SpotifyRef?
```

### Track

```yaml
name: string
artist_ids: string[] (references Artist.id)
album_id: string? (references Album.id)
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
image_url: string?
```
