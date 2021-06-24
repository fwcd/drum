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
  Album = Struct.new(
    :id,
    :name,
    :artist_ids,
    :spotify
  )

  # Spotify-specific metadata about the album.
  #
  # @!attribute id
  #   @return [String] The id of the album on Spotify
  # @!attribute image_url
  #   @return [String] The URL of the album cover art on Spotify
  AlbumSpotify = Struct.new(
    :id,
    :image_url
  )
end
