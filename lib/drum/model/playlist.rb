require 'drum/utils/try'

module Drum
  # TODO: Smart playlists!

  # A list of tracks with metadata.
  #
  # Note that arrays are intentionally used internally to represent
  # unordered collections of objects that are actually identified
  # by their internal ids so the structure of this classes objects
  # are isomorphic to their serialized (JSON/YAML) representations.
  #
  # @!attribute name
  #   @return [String] The name of the playlist
  # @!attribute description
  #   @return [optional, String] A description of the playlist
  # @!attribute author_id
  #   @return [optional, String] The author id
  # @!attribute users
  #   @return [optional, Array<User>] A list of users used anywhere in the playlist, order doesn't matter
  # @!attribute artists
  #   @return [optional, Array<Artist>] A list of artists used anywhere in the playlist, order doesn't matter
  # @!attribute albums
  #   @return [optional, Array<Album>] A list of albums used anywhere in the playlist, order doesn't matter
  # @!attribute tracks
  #   @return [optional, Array<Track>] The list of tracks of the playlist, order matters here
  # @!attribute spotify
  #   @return [optional, PlaylistSpotify] Spotify-specific metadata
  Playlist = Struct.new(
    :name, :description,
    :author_id, :users, :artists, :albums, :tracks,
    :spotify
  ) do
    # Parses a playlist from a nested Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [Playlist] The parsed playlist
    def self.deserialize(h)
      Playlist.new(
        name: h['name'],
        description: h['description'],
        author_id: h['author_id'],
        users: h['users']&.map { |u| User.deserialize(u) } || [],
        artists: h['artists']&.map { |a| Artist.deserialize(a) } || [],
        albums: h['albums']&.map { |a| Album.deserialize(a) } || [],
        tracks: h['tracks']&.map { |t| Track.deserialize(t) } || [],
        spotify: h['spotify'].try { |p| PlaylistSpotify.deserialize(p) }
      )
    end
  end

  # Spotify-specific metadata about the playlist.
  #
  # @!attribute id
  #   @return [String] The id of the playlist on Spotify
  # @!attribute public
  #   @return [optional, Boolean] Whether the playlist is public on Spotify
  # @!attribute collaborative
  #   @return [optional, Boolean] Whether the playlist is collaborative on Spotify
  # @!attribute image_url
  #   @return [optional, String] The playlist cover URL
  PlaylistSpotify = Struct.new(
    :id,
    :public, :collaborative,
    :image_url
  ) do
    # Parses spotify metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [PlaylistSpotify] The parsed metadata
    def self.deserialize(h)
      PlaylistSpotify.new(
        id: h['id'],
        public: h['public'],
        collaborative: h['collaborative'],
        image_url: h['image_url']
      )
    end
  end
end
