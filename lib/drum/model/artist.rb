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
  )

  # Spotify-specific metadata about the artist.
  #
  # @!attribute id
  #   @return [String] The id of the artist on Spotify
  ArtistSpotify = Struct.new(
    :id
  )
end
