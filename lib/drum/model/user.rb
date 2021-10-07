module Drum
  # A user.
  #
  # @!attribute id
  #   @return [String] The (internal) id of the user
  # @!attribute display_name
  #   @return [optional, String] The general formatted name of the user
  # @!attribute spotify
  #   @return [optional, UserSpotify] Spotify-specific metadata
  User = Struct.new(
    :id,
    :display_name,
    :spotify,
    keyword_init: true
  ) do
    # Parses a user from a nested Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [User] The parsed user
    def self.deserialize(h)
      User.new(
        id: h['id'],
        display_name: h['display_name'],
        spotify: h['spotify'].try { |s| UserSpotify.deserialize(s) }
      )
    end

    # Serializes the user to a nested Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'id' => self.id,
        'display_name' => self.display_name,
        'spotify' => self.spotify&.serialize
      }.compact
    end
  end

  # Spotify-specific metadata about the user.
  #
  # @!attribute id
  #   @return [String] The id of the artist on Spotify
  # @!attribute display_name
  #   @return [optional, String] The displayed/formatted name of the user on Spotify
  UserSpotify = Struct.new(
    :id,
    :display_name,
    keyword_init: true
  ) do
    # Parses Spotify metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [UserSpotify] The parsed user
    def self.deserialize(h)
      UserSpotify.new(
        id: h['id'],
        display_name: h['display_name']
      )
    end

    # Serializes the metadata to a Hash that uses string keys.
    #
    # @return [Hash<String, Object>] The serialized representation
    def serialize
      {
        'id' => self.id,
        'display_name' => self.display_name
      }.compact
    end
  end
end
