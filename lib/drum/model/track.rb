module Drum
  # A track/song.
  #
  # @!attribute name
  #  @return [String] The name of the track
  # @!attribute artist_ids
  #  @return [Array<String>] The (internal) artist ids
  # @!attribute album_id
  #  @return [optional, String] The (internal) album id
  # @!attribute duration_ms
  #  @return [optional, Float] The duration of the track in milliseconds
  # @!attribute explicit
  #  @return [optional, Boolean] Whether the track is explicit
  # @!attribute isrc
  #  @return [optional, String] The International Standard Recording Code of this track
  # @!attribute spotify
  #  @return [optional, SpotifyRef] The Spotify location of the song
  Track = Struct.new(
    :name,
    :artist_ids, :album_id,
    :duration_ms, :explicit,
    :isrc, :spotify
  )
end
