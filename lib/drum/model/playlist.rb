require 'drum/utils/ext'
require 'set'

module Drum
  # TODO: Smart playlists!

  # A list of tracks with metadata.
  #
  # Note that arrays are intentionally used internally to represent
  # unordered collections of objects that are actually identified
  # by their internal ids so the structure of this classes objects
  # are isomorphic to their serialized (JSON/YAML) representations.
  #
  # @!attribute name
  #   @return [String] The name of the playlist
  # @!attribute description
  #   @return [optional, String] A description of the playlist
  # @!attribute author_id
  #   @return [optional, String] The author id
  # @!attribute users
  #   @return [optional, Array<User>] A list of users used anywhere in the playlist, order doesn't matter
  # @!attribute artists
  #   @return [optional, Array<Artist>] A list of artists used anywhere in the playlist, order doesn't matter
  # @!attribute albums
  #   @return [optional, Array<Album>] A list of albums used anywhere in the playlist, order doesn't matter
  # @!attribute tracks
  #   @return [optional, Array<Track>] The list of tracks of the playlist, order matters here
  # @!attribute spotify
  #   @return [optional, PlaylistSpotify] Spotify-specific metadata
  class Playlist < Struct.new(
    :name, :description,
    :author_id, :users, :artists, :albums, :tracks,
    :spotify,
    keyword_init: true
  )
    def initialize(**kwargs)
      super(**kwargs)

      # Internal sets for fast lookups in the store_x methods
      @user_ids = Set[]
      @artist_ids = Set[]
      @album_ids = Set[]
      @track_ids = Set[]
    end

    # TODO: Handle merging in the store_x methods?

    # Stores a user if it does not exist already.
    #
    # @param [User] user The user to store.
    def store_user(user)
      unless @user_ids.include?(user.id)
        @user_ids.add(user.id)
        if self.users.nil?
          self.users = []
        end
        self.users << user
      end
    end

    # Stores an artist if it does not exist already.
    #
    # @param [Artist] artist The artist to store.
    def store_artist(artist)
      unless @artist_ids.include?(artist.id)
        @artist_ids.add(artist.id)
        if self.artists.nil?
          self.artists = []
        end
        self.artists << artist
      end
    end

    # Stores an album if it does not exist already.
    #
    # @param [Album] album The album to store.
    def store_album(album)
      unless @album_ids.include?(album.id)
        @album_ids.add(album.id)
        if self.albums.nil?
          self.albums = []
        end
        self.albums << album
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
        users: h['users']&.map { |u| User.deserialize(u) },
        artists: h['artists']&.map { |a| Artist.deserialize(a) },
        albums: h['albums']&.map { |a| Album.deserialize(a) },
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
        'users' => self.users&.map { |u| u.serialize },
        'artists' => self.artists&.map { |a| a.serialize },
        'albums' => self.albums&.map { |a| a.serialize },
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
