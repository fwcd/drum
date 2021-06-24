module Drum
  # A user.
  #
  # @!attribute id
  #   @return [String] The (internal) id of the user
  # @!attribute spotify
  #   @return [optional, UserSpotify] Spotify-specific metadata
  User = Struct.new(
    :id,
    :display_name,
    :spotify
  )

  # Spotify-specific metadata about the user.
  #
  # @!attribute id
  #   @return [String] The id of the artist on Spotify
  # @!attribute display_name
  #   @return [optional, String] The displayed/formatted name of the user
  UserSpotify = Struct.new(
    :id,
    :display_name
  )
end
