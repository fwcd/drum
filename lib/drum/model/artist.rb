module Drum
  # An artist.
  #
  # @!attribute id
  #  @return [String] The (internal) id of the artist
  # @!attribute name
  #  @return [optional, String] The displayed/formatted name of the artist
  # @!attribute spotify
  #  @return [optional, SpotifyRef] The Spotify location of the artist
  Artist = Struct.new(
    :id,
    :name,
    :spotify
  )
end
