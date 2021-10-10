module Drum
  # An artist.
  #
  # @!attribute id
  #  @return [String] The (internal) id of the artist
  # @!attribute name
  #  @return [optional, String] The displayed/formatted name of the artist
  # @!attribute spotify
  #  @return [optional, ArtistSpotify] Spotify-specific metadata
  Artist = Struct.new(
    :id,
    :name,
    :spotify,
    keyword_init: true
  ) do
    # Parses an artist from a nested Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [Artist] The parsed artist
    def self.deserialize(h)
      Artist.new(
        id: h['id'],
        name: h['name'],
        spotify: h['spotify'].try { |s| ArtistSpotify.deserialize(s) }
      )
    end

    # Serializes the artist to a nested Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'id' => self.id,
        'name' => self.name,
        'spotify' => self.spotify&.serialize
      }.compact
    end
  end

  # Spotify-specific metadata about the artist.
  #
  # @!attribute id
  #   @return [String] The id of the artist on Spotify
  # @!attribute image_url
  #   @return [optional, String] An image of the artist
  ArtistSpotify = Struct.new(
    :id,
    :image_url,
    keyword_init: true
  ) do
    # Parses spotify metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [ArtistSpotify] The parsed metadata
    def self.deserialize(h)
      ArtistSpotify.new(
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
end
