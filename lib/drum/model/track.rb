
module Drum
  # TODO: Add Spotify's audio features

  # A track/song.
  #
  # @!attribute name
  #  @return [String] The name of the track
  # @!attribute artist_ids
  #  @return [Array<String>] The (internal) artist ids
  # @!attribute composer_ids
  #  @return [optional, Array<String>] The (internal) composer ids
  # @!attribute genres
  #  @return [optional, Array<String>] The track's genre names
  # @!attribute album_id
  #  @return [optional, String] The (internal) album id
  # @!attribute duration_ms
  #  @return [optional, Float] The duration of the track in milliseconds
  # @!attribute explicit
  #  @return [optional, Boolean] Whether the track is explicit
  # @!attribute released_at
  #  @return [optional, DateTime] The date/time the this track was released
  # @!attribute added_at
  #  @return [optional, DateTime] The date/time the this track was added to the playlist
  # @!attribute added_by
  #  @return [optional, String] The user id of the user who added this track to the playlist
  # @!attribute isrc
  #  @return [optional, String] The International Standard Recording Code of this track
  # @!attribute spotify
  #  @return [optional, TrackSpotify] Spotify-specific metadata
  # @!attribute applemusic
  #   @return [optional, TrackAppleMusic] Apple Music-specific metadata
  Track = Struct.new(
    :name,
    :artist_ids, :composer_ids, :album_id,
    :genres,
    :duration_ms, :explicit,
    :released_at, :added_at, :added_by,
    :isrc, :spotify, :applemusic,
    keyword_init: true
  ) do
    def initialize(*)
      super
      self.artist_ids ||= []
      self.composer_ids ||= []
      self.genres ||= []
    end

    # Parses a track from a nested Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [Track] The parsed track
    def self.deserialize(h)
      Track.new(
        name: h['name'],
        artist_ids: h['artist_ids'],
        composer_ids: h['composer_ids'],
        genres: h['genres'],
        album_id: h['album_id'],
        duration_ms: h['duration_ms'],
        explicit: h['explicit'],
        released_at: h['released_at'].try { |d| DateTime.parse(d) },
        added_at: h['added_at'].try { |d| DateTime.parse(d) },
        added_by: h['added_by'],
        isrc: h['isrc'],
        spotify: h['spotify'].try { |s| TrackSpotify.deserialize(s) },
        applemusic: h['applemusic'].try { |s| TrackAppleMusic.deserialize(s) }
      )
    end

    # Serializes the track to a nested Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'name' => self.name,
        'artist_ids' => self.artist_ids,
        'composer_ids' => (self.composer_ids unless self.composer_ids.empty?),
        'genres' => (self.genres unless self.genres.empty?),
        'album_id' => self.album_id,
        'duration_ms' => self.duration_ms,
        'explicit' => self.explicit,
        'released_at' => self.released_at&.iso8601,
        'added_at' => self.added_at&.iso8601,
        'added_by' => self.added_by,
        'isrc' => self.isrc,
        'spotify' => self.spotify&.serialize,
        'applemusic' => self.applemusic&.serialize
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

  # Apple Music-specific metadata about the track.
  #
  # @!attribute library_id
  #   @return [optional, String] The library-internal id of the track
  # @!attribute catalog_id
  #   @return [optional, String] The global catalog id of the track
  # @!attribute preview_url
  #   @return [optional, String] A short preview of the song audio
  TrackAppleMusic = Struct.new(
    :library_id, :catalog_id,
    :preview_url,
    keyword_init: true
  ) do
    # Parses Apple Music metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [TrackAppleMusic] The parsed metadata
    def self.deserialize(h)
      TrackAppleMusic.new(
        library_id: h['library_id'],
        catalog_id: h['catalog_id'],
        preview_url: h['preview_url']
      )
    end

    # Serializes the metadata to a Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'library_id' => self.library_id,
        'catalog_id' => self.catalog_id,
        'preview_url' => self.preview_url
      }.compact
    end
  end
end
