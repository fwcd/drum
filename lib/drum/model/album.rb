module Drum
  # A album, i.e. a composition of tracks by an artist.
  #
  # @!attribute id
  #  @return [String] The (internal) id of the album
  # @!attribute name
  #  @return [String] The name of the album
  # @!attribute artist_ids
  #  @return [Array<String>] The artist ids of the album
  # @!attribute spotify
  #  @return [optional, AlbumSpotify] Spotify-specific metadata
  # @!attribute applemusic
  #  @return [optional, AlbumAppleMusic] Apple Music-specific metadata
  Album = Struct.new(
    :id,
    :name,
    :artist_ids,
    :spotify, :applemusic,
    keyword_init: true
  ) do
    def initialize(*)
      super
      self.artist_ids ||= []
    end

    # Parses an album from a nested Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [Album] The parsed album
    def self.deserialize(h)
      Album.new(
        id: h['id'],
        name: h['name'],
        artist_ids: h['artist_ids'],
        spotify: h['spotify'].try { |s| AlbumSpotify.deserialize(s) },
        applemusic: h['applemusic'].try { |s| AlbumAppleMusic.deserialize(s) }
      )
    end

    # Serializes the album to a nested Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'id' => self.id,
        'name' => self.name,
        'artist_ids' => self.artist_ids,
        'spotify' => self.spotify&.serialize,
        'applemusic' => self.applemusic&.serialize
      }.compact
    end
  end

  # Spotify-specific metadata about the album.
  #
  # @!attribute id
  #   @return [String] The id of the album on Spotify
  # @!attribute image_url
  #   @return [String] The URL of the album cover art on Spotify
  AlbumSpotify = Struct.new(
    :id,
    :image_url,
    keyword_init: true
  ) do
    # Parses spotify metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [AlbumSpotify] The parsed metadata
    def self.deserialize(h)
      AlbumSpotify.new(
        id: h['id'],
        image_url: h['image_url']
      )
    end

    # Serializes the metadata to a Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'id' => self.id,
        'image_url' => self.image_url
      }.compact
    end
  end

  # Apple Music-specific metadata about the album.
  #
  # @!attribute image_url
  #   @return [optional, String] The cover image of the album
  AlbumAppleMusic = Struct.new(
    :image_url,
    keyword_init: true
  ) do
    # Parses Apple Music metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [AlbumAppleMusic] The parsed metadata
    def self.deserialize(h)
      AlbumAppleMusic.new(
        image_url: h['image_url']
      )
    end

    # Serializes the metadata to a Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'image_url' => self.image_url
      }.compact
    end
  end
end
