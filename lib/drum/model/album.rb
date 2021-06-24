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
  #  @return [optional, SpotifyRef] The location on Spotify
  Album = Struct.new(
    :id,
    :name,
    :artist_ids,
    :spotify
  )
end
