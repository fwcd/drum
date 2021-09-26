
module Drum
  # TODO: Add Spotify's audio features

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
  # @!attribute added_at
  #  @return [optional, DateTime] The date/time the this track was added to the playlist
  # @!attribute added_by
  #  @return [optional, String] The user id of the user who added this track to the playlist
  # @!attribute isrc
  #  @return [optional, String] The International Standard Recording Code of this track
  # @!attribute spotify
  #  @return [optional, TrackSpotify] Spotify-specific metadata
  Track = Struct.new(
    :name,
    :artist_ids, :album_id,
    :duration_ms, :explicit,
    :added_at, :added_by,
    :isrc, :spotify,
    keyword_init: true
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
        added_at: h['added_at'].try { |d| DateTime.parse(d) },
        added_by: h['added_by'],
        isrc: h['isrc'],
        spotify: h['spotify'].try { |s| TrackSpotify.deserialize(s) }
      )
    end

    # Serializes the track to a nested Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'name' => self.name,
        'artist_ids' => self.artist_ids,
        'album_id' => self.album_id,
        'duration_ms' => self.duration_ms,
        'explicit' => self.explicit,
        'added_at' => self.added_at&.iso8601,
        'added_by' => self.added_by,
        'isrc' => self.isrc,
        'spotify' => self.spotify&.serialize
      }.compact
    end
  end

  # Spotify-specific metadata about the track.
  #
  # @!attribute id
  #   @return [String] The id of the track on Spotify
  TrackSpotify = Struct.new(
    :id,
    keyword_init: true
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

    # Serializes the metadata to a Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'id' => self.id
      }.compact
    end
  end
end
