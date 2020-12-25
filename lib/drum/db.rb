require 'sequel'

module Drum
  def self.setup_db(uri)
    db = Sequel.connect(uri)
    
    db.create_table?(:tracks) do
      primary_key :id
      # Generic metadata
      String :title
      Integer :duration_ms
      TrueClass :explicit
      String :isrc
      # General audio features
      Float :tempo            # beats per minute
      Integer :key            # 0 = C, 1 = C#/D, ...
      Integer :mode           # 0 = minor, 1 = major
      Integer :time_signature # beats per measure
      # Specific audio features
      Float :acousticness     # 0.0 to 1.0, 1.0 = high confidence
      Float :danceability     # 0.0 to 1.0, 1.0 = very danceable
      Float :energy           # 0.0 to 1.0, 1.0 = high energy
      Float :instrumentalness # 0.0 to 1.0, > 0.5 = instrumentals
      Float :liveness         # 0.0 to 1.0, > 0.8 = live audience very likely
      Float :loudness         # dB
      Float :speechiness      # 0.0 to 1.0, > 0.6 = only spoken words
      Float :valence          # 0.0 to 1.0, musical positiveness, higher = happier
    end
    
    db.create_table?(:artists) do
      primary_key :id
      String :name
    end
    
    db.create_table?(:track_artists) do
      foreign_key :artist_id, :artists
      foreign_key :track_id, :tracks
      primary_key [:artist_id, :track_id]
    end
    
    db.create_table?(:users) do
      primary_key :id
      String :name
      String :display_name
    end

    db.create_table?(:playlists) do
      primary_key :id
      String :name
      String :description
      foreign_key :user_id, :users
    end
    
    db.create_table?(:playlist_tracks) do
      foreign_key :playlist_id, :playlists
      foreign_key :track_id, :tracks
      primary_key [:playlist_id, :track_id]
      Integer :track_index # within the playlist
      DateTime :added_at
      foreign_key :user_id, :users
    end

    return db
  end
end
