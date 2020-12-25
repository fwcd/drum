require 'sequel'

module Drum
  def self.setup_db(uri)
    db = Sequel.connect(uri)
    
    # TODO: Albums, track-album relation, smart playlists, playlist folders,
    #       separate tables for externals locations/ids (e.g. 'tracks_spotify',
    #       'tracks_local' holding URIs/file paths/...)
    
    db.create_table?(:tracks) do
      primary_key :id
      # Generic metadata
      String :title, null: false
      Integer :duration_ms, null: false
      TrueClass :explicit, null: true
      String :isrc, null: true
      # General audio features
      Float :tempo, null: true            # beats per minute
      Integer :key, null: true            # 0 = C, 1 = C#/D, ...
      Integer :mode, null: true           # 0 = minor, 1 = major
      Integer :time_signature, null: true # beats per measure
      # Specific audio features
      Float :acousticness, null: true     # 0.0 to 1.0, 1.0 = high confidence
      Float :danceability, null: true     # 0.0 to 1.0, 1.0 = very danceable
      Float :energy, null: true           # 0.0 to 1.0, 1.0 = high energy
      Float :instrumentalness, null: true # 0.0 to 1.0, > 0.5 = instrumentals
      Float :liveness, null: true         # 0.0 to 1.0, > 0.8 = live audience very likely
      Float :loudness, null: true         # dB
      Float :speechiness, null: true      # 0.0 to 1.0, > 0.6 = only spoken words
      Float :valence, null: true          # 0.0 to 1.0, musical positiveness, higher = happier
    end
    
    db.create_table?(:artists) do
      primary_key :id
      String :name, null: false
    end
    
    db.create_table?(:track_artists) do
      foreign_key :artist_id, :artists, null: false
      foreign_key :track_id, :tracks, null: false
      primary_key [:artist_id, :track_id]
    end
    
    db.create_table?(:users) do
      primary_key :id
      String :name, null: false
      String :display_name, null: true
    end

    db.create_table?(:playlists) do
      primary_key :id
      String :name, null: false
      String :description, null: true
      foreign_key :user_id, :users
    end
    
    db.create_table?(:playlist_tracks) do
      foreign_key :playlist_id, :playlists, null: false
      foreign_key :track_id, :tracks, null: false
      primary_key [:playlist_id, :track_id]
      Integer :track_index, null: true # within the playlist, null if unordered
      DateTime :added_at, null: true
      foreign_key :user_id, :users, null: false
    end

    return db
  end
end
