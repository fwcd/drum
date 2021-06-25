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
    :spotify
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
  end

  # Spotify-specific metadata about the artist.
  #
  # @!attribute id
  #   @return [String] The id of the artist on Spotify
  ArtistSpotify = Struct.new(
    :id
  ) do
    # Parses spotify metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [ArtistSpotify] The parsed metadata
    def self.deserialize(h)
      AlbumSpotify.new(
        id: h['id']
      )
    end
  end
end
