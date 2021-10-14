require 'drum/utils/ext'
require 'set'

module Drum
  # TODO: Smart playlists!
  # TODO: Add created_at/added_at or similar
  #       (the Apple Music API provides us with a 'dateAdded', perhaps Spotify has something similar?)

  # A list of tracks with metadata.
  #
  # @!attribute id
  #   @return [String] An internal id for the playlist
  # @!attribute name
  #   @return [String] The name of the playlist
  # @!attribute description
  #   @return [optional, String] A description of the playlist
  # @!attribute author_id
  #   @return [optional, String] The author id
  # @!attribute path
  #   @return [optional, Array<String>] The path of parent 'folders' to this playlist.
  # @!attribute users
  #   @return [optional, Hash<String, User>] A hash of ids to users used somewhere in the playlist
  # @!attribute artists
  #   @return [optional, Hash<String, Artist>] A hash of ids to artists used somewhere in the playlist
  # @!attribute albums
  #   @return [optional, Hash<String, Album>] A hash of ids to albums used somewhere in the playlist
  # @!attribute tracks
  #   @return [optional, Array<Track>] The list of tracks of the playlist, order matters here
  # @!attribute spotify
  #   @return [optional, PlaylistSpotify] Spotify-specific metadata
  # @!attribute applemusic
  #   @return [optional, PlaylistAppleMusic] Apple Music-specific metadata
  class Playlist < Struct.new(
    :id, :name, :description,
    :path,
    :author_id,
    :users, :artists, :albums, :tracks,
    :spotify, :applemusic,
    keyword_init: true
  )
    def initialize(*)
      super
      self.path ||= []
      self.users ||= {}
      self.artists ||= {}
      self.albums ||= {}
      self.tracks ||= []
    end

    # TODO: Handle merging in the store_x methods?

    # Stores a user if it does not exist already.
    #
    # @param [User] user The user to store.
    def store_user(user)
      unless self.users.key?(user.id)
        self.users[user.id] = user
      end
    end

    # Stores an artist if it does not exist already.
    #
    # @param [Artist] artist The artist to store.
    def store_artist(artist)
      unless self.artists.key?(artist.id)
        self.artists[artist.id] = artist
      end
    end

    # Stores an album if it does not exist already.
    #
    # @param [Album] album The album to store.
    def store_album(album)
      unless self.albums.key?(album.id)
        self.albums[album.id] = album
      end
    end

    # Stores a track.
    #
    # @param [Track] track The track to store.
    def store_track(track)
      self.tracks << track
    end

    # Parses a playlist from a nested Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [Playlist] The parsed playlist
    def self.deserialize(h)
      Playlist.new(
        id: h['id'],
        name: h['name'],
        description: h['description'],
        author_id: h['author_id'],
        path: h['path'],
        users: h['users']&.map { |u| User.deserialize(u) }&.to_h_by_id,
        artists: h['artists']&.map { |a| Artist.deserialize(a) }&.to_h_by_id,
        albums: h['albums']&.map { |a| Album.deserialize(a) }&.to_h_by_id,
        tracks: h['tracks']&.map { |t| Track.deserialize(t) },
        spotify: h['spotify'].try { |s| PlaylistSpotify.deserialize(s) },
        applemusic: h['applemusic'].try { |a| PlaylistAppleMusic.deserialize(a) }
      )
    end

    # Serializes the playlist to a nested Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'id' => self.id,
        'name' => self.name,
        'description' => self.description,
        'author_id' => self.author_id,
        'path' => (self.path unless self.path.empty?),
        'users' => (self.users.each_value.map { |u| u.serialize } unless self.users.empty?),
        'artists' => (self.artists.each_value.map { |a| a.serialize } unless self.artists.empty?),
        'albums' => (self.albums.each_value.map { |a| a.serialize } unless self.albums.empty?),
        'tracks' => (self.tracks.map { |t| t.serialize } unless self.tracks.empty?),
        'spotify' => self.spotify&.serialize,
        'applemusic' => self.applemusic&.serialize
      }.compact
    end
  end

  # Spotify-specific metadata about the playlist.
  #
  # @!attribute id
  #   @return [String] The id of the playlist on Spotify
  # @!attribute public
  #   @return [optional, Boolean] Whether the playlist is public on Spotify
  # @!attribute collaborative
  #   @return [optional, Boolean] Whether the playlist is collaborative on Spotify
  # @!attribute image_url
  #   @return [optional, String] The playlist cover URL
  PlaylistSpotify = Struct.new(
    :id,
    :public, :collaborative,
    :image_url,
    keyword_init: true
  ) do
    # Parses spotify metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [PlaylistSpotify] The parsed metadata
    def self.deserialize(h)
      PlaylistSpotify.new(
        id: h['id'],
        public: h['public'],
        collaborative: h['collaborative'],
        image_url: h['image_url']
      )
    end

    # Serializes the metadata to a Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'id' => self.id,
        'public' => self.public,
        'collaborative' => self.collaborative,
        'image_url' => self.image_url
      }.compact
    end
  end

  # TODO: Add image URL to Apple Music metadata?

  # Apple Music-specific metadata about the playlist.
  #
  # @!attribute library_id
  #   @return [optional, String] The library-internal id of the playlist
  # @!attribute global_id
  #   @return [optional, String] The global id of the playlist (implies that it is available through the catalog API)
  # @!attribute public
  #   @return [optional, Boolean] Whether the playlist is public
  # @!attribute editable
  #   @return [optional, Boolean] Whether the playlist is editable
  # @!attribute image_url
  #   @return [optional, String] The playlist cover image, if present
  PlaylistAppleMusic = Struct.new(
    :library_id, :global_id,
    :public, :editable, :image_url,
    keyword_init: true
  ) do
    # Parses Apple Music metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [PlaylistAppleMusic] The parsed metadata
    def self.deserialize(h)
      PlaylistAppleMusic.new(
        library_id: h['library_id'],
        global_id: h['global_id'],
        public: h['public'],
        editable: h['editable'],
        image_url: h['image_url']
      )
    end

    # Serializes the metadata to a Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'library_id' => self.library_id,
        'global_id' => self.global_id,
        'public' => self.public,
        'editable' => self.editable,
        'image_url' => self.image_url
      }.compact
    end
  end
end
