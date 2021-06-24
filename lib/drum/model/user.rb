module Drum
  # A user.
  #
  # @!attribute id
  #  @return [String] The (internal) id of this user
  # @!attribute display_name
  #  @return [optional, String] The displayed/formatted name of the user
  # @!attribute spotify
  #  @return [optional, SpotifyRef] The Spotify location of the user
  User = Struct.new(
    :id,
    :display_name,
    :spotify
  )
end
