require 'drum/utils/ext'
require 'set'

module Drum
  # TODO: Smart playlists!

  # A list of tracks with metadata.
  #
  # @!attribute name
  #   @return [String] The name of the playlist
  # @!attribute description
  #   @return [optional, String] A description of the playlist
  # @!attribute author_id
  #   @return [optional, String] The author id
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
  class Playlist < Struct.new(
    :name, :description,
    :author_id,
    :users, :artists, :albums, :tracks,
    :spotify,
    keyword_init: true
  )
    # TODO: Handle merging in the store_x methods?

    # Stores a user if it does not exist already.
    #
    # @param [User] user The user to store.
    def store_user(user)
      if self.users.nil?
        self.users = {}
      end
      unless self.users.key?(user.id)
        self.users[user.id] = user
      end
    end

    # Stores an artist if it does not exist already.
    #
    # @param [Artist] artist The artist to store.
    def store_artist(artist)
      if self.artists.nil?
        self.artists = {}
      end
      unless self.artists.key?(artist.id)
        self.artists[artist.id] = artist
      end
    end

    # Stores an album if it does not exist already.
    #
    # @param [Album] album The album to store.
    def store_album(album)
      if self.albums.nil?
        self.albums = {}
      end
      unless self.albums.key?(album.id)
        self.albums[album.id] = album
      end
    end

    # Stores a track.
    #
    # @param [Track] track The track to store.
    def store_track(track)
      if self.tracks.nil?
        self.tracks = []
      end
      self.tracks << track
    end

    # Parses a playlist from a nested Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [Playlist] The parsed playlist
    def self.deserialize(h)
      Playlist.new(
        name: h['name'],
        description: h['description'],
        author_id: h['author_id'],
        users: h['users']&.map { |u| User.deserialize(u) }&.map { |u| [u.id, u] }&.to_h,
        artists: h['artists']&.map { |a| Artist.deserialize(a) }&.map { |a| [a.id, a] }&.to_h,
        albums: h['albums']&.map { |a| Album.deserialize(a) }&.map { |a| [a.id, a] }&.to_h,
        tracks: h['tracks']&.map { |t| Track.deserialize(t) },
        spotify: h['spotify'].try { |s| PlaylistSpotify.deserialize(s) }
      )
    end

    # Serializes the playlist to a nested Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'name' => self.name,
        'description' => self.description,
        'author_id' => self.author_id,
        'users' => self.users&.each_value&.map { |u| u.serialize },
        'artists' => self.artists&.each_value&.map { |a| a.serialize },
        'albums' => self.albums&.each_value&.map { |a| a.serialize },
        'tracks' => self.tracks&.map { |t| t.serialize },
        'spotify' => self.spotify&.serialize
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
end
