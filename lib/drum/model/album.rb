require 'drum/utils/kwstruct'

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
  Album = KeywordStruct.new(
    :id,
    :name,
    :artist_ids,
    :spotify
  ) do
    # Parses an album from a nested Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [Album] The parsed album
    def self.deserialize(h)
      Album.new(
        id: h['id'],
        name: h['name'],
        artist_ids: h['artist_ids'],
        spotify: h['spotify'].try { |s| AlbumSpotify.deserialize(s) }
      )
    end
  end

  # Spotify-specific metadata about the album.
  #
  # @!attribute id
  #   @return [String] The id of the album on Spotify
  # @!attribute image_url
  #   @return [String] The URL of the album cover art on Spotify
  AlbumSpotify = KeywordStruct.new(
    :id,
    :image_url
  ) do
    # Parses spotify metadata from a Hash that uses string keys.
    #
    # @param [Hash<String, Object>] h The Hash to be parsed
    # @return [AlbumSpotify] The parsed metadata
    def self.deserialize(h)
      AlbumSpotify.new(
        id: h['id'],
        image_url: h['image_url']
      )
    end
  end
end
