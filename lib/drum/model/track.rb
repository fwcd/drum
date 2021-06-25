require 'drum/utils/kwstruct'

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
  #  @return [optional, TrackSpotify] Spotify-specific metadata
  Track = KeywordStruct.new(
    :name,
    :artist_ids, :album_id,
    :duration_ms, :explicit,
    :isrc, :spotify
  ) do
    # Parses a track from a nested Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [Track] The parsed track
    def self.deserialize(h)
      Track.new(
        name: h['name'],
        artist_ids: h['artist_ids'],
        album_id: h['album_id'],
        duration_ms: h['duration_ms'],
        explicit: h['explicit'],
        isrc: h['isrc'],
        spotify: h['spotify'].try { |s| TrackSpotify.deserialize(s) }
      )
    end
  end

  # Spotify-specific metadata about the track.
  #
  # @!attribute id
  #   @return [String] The id of the track on Spotify
  TrackSpotify = KeywordStruct.new(
    :id
  ) do
    # Parses spotify metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [TrackSpotify] The parsed metadata
    def self.deserialize(h)
      TrackSpotify.new(
        id: h['id']
      )
    end
  end
end
