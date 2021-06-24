module Drum
  # TODO: Smart playlists!

  # A list of tracks with metadata.
  #
  # Note that arrays are intentionally used internally to represent
  # unordered collections of objects that are actually identified
  # by their internal ids so the structure of this classes objects
  # are isomorphic to their serialized (JSON/YAML) representations.
  #
  # @!attribute [r] name
  #   @return [String] The name of the playlist
  # @!attribute [r] description
  #   @return [optional, String] A description of the playlist
  # @!attribute [r] author
  #   @return [optional, String] The author id (references User.id)
  # @!attribute [r] users
  #   @return [optional, Array<User>] A list of users used anywhere in the playlist, order doesn't matter
  # @!attribute [r] artists
  #   @return [optional, Array<Artist>] A list of artists used anywhere in the playlist, order doesn't matter
  # @!attribute [r] albums
  #   @return [optional, Array<Album>] A list of albums used anywhere in the playlist, order doesn't matter
  # @!attribute [r] tracks
  #   @return [optional, Array<Track>] The list of tracks of the playlist, order matters here
  Playlist = Struct.new(
    :name, :description,
    :author, :users, :artists, :albums, :tracks
  )
end
