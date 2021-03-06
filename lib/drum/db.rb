require 'sequel'

module Drum
  def self.setup_db(uri)
    db = Sequel.connect(uri)
    
    # TODO: Smart playlists

    # Tracks
    
    db.create_table?(:tracks) do
      primary_key :id
      # Generic metadata
      String :name, null: false
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

    # Artists
    
    db.create_table?(:artists) do
      primary_key :id
      String :name, null: false
    end
    
    db.create_table?(:track_artists) do
      foreign_key :artist_id, :artists, null: false
      foreign_key :track_id, :tracks, null: false
      primary_key [:artist_id, :track_id]
    end

    # Albums

    db.create_table?(:albums) do
      primary_key :id
      String :name, null: false
      String :type, null: false        # 'album', 'single' or 'compilation'
      String :release_date, null: true # e.g. 2020-12-24, 2020-12 or 2020
    end

    db.create_table?(:album_artists) do
      foreign_key :artist_id, :artists, null: false
      foreign_key :album_id, :albums, null: false
      primary_key [:artist_id, :album_id]
    end

    db.create_table?(:album_tracks) do
      foreign_key :album_id, :albums, null: false
      foreign_key :track_id, :tracks, null: false
      primary_key [:album_id, :track_id]
      Integer :track_index, null: false # within the album
      Integer :disc_number, null: false # 1 or higher
    end

    # Users
    
    db.create_table?(:users) do
      primary_key :id
    end

    # Playlists

    db.create_table?(:playlists) do
      primary_key :id
      String :name, null: false
      String :description, null: true
      foreign_key :user_id, :users, null: true # the creator of the playlist
    end

    db.create_table?(:playlist_parents) do
      # the parent is a playlist folder
      foreign_key :playlist_id, :playlists, null: false
      foreign_key :parent_id, :playlists, null: false
      primary_key [:playlist_id]
    end
    
    db.create_table?(:playlist_tracks) do
      foreign_key :playlist_id, :playlists, null: false
      foreign_key :track_id, :tracks, null: false
      primary_key [:playlist_id, :track_id]
      Integer :track_index, null: true          # within the playlist, null if unordered
      DateTime :added_at, null: true            # the date the song was added
      foreign_key :added_by, :users, null: true # the user (id) that added the song
    end

    # External services/locators

    db.create_table?(:services) do
      # a music streaming service (or similar, e.g. 'local' could be a service too)
      primary_key :id
      String :name, null: false, unique: true
    end

    db.create_table?(:user_services) do
      # locates a user on a service
      String :external_id, null: false
      foreign_key :user_id, null: false
      foreign_key :service_id, :services, null: false
      primary_key [:user_id, :service_id]
      String :display_name, null: true
    end

    db.create_table?(:track_services) do
      # locates a track on a service
      String :external_id, null: false
      primary_key [:external_id]
      foreign_key :track_id, :tracks, null: false
      foreign_key :service_id, :services, null: false
      String :uri, null: true, unique: true
    end

    db.create_table?(:album_services) do
      # locates an album on a service
      String :external_id, null: false
      primary_key [:external_id]
      foreign_key :album_id, :albums, null: false
      foreign_key :service_id, :services, null: false
      String :uri, null: true, unique: true
      String :image_uri, null: true
    end

    db.create_table?(:artist_services) do
      # locates an artist on a service
      String :external_id, null: false
      primary_key [:external_id]
      foreign_key :artist_id, :artists, null: false
      foreign_key :service_id, :services, null: false
      String :uri, null: true, unique: true
      String :image_uri, null: true
    end

    db.create_table?(:playlist_services) do
      # locates a playlist on a service
      String :external_id, null: false
      primary_key [:external_id]
      foreign_key :playlist_id, :playlists, null: false
      foreign_key :service_id, :services, null: false
      String :uri, null: true, unique: true
      String :image_uri, null: true
      String :preview_uri, null: true # for Spotify a 30s MP3
      TrueClass :collaborative, null: true
      TrueClass :public, null: true
    end

    # User library

    db.create_table?(:libraries) do
      primary_key :id
      String :name, unique: true, null: false
      foreign_key :service_id, :services, null: true
      foreign_key :user_id, :users, null: true
    end

    db.create_table?(:library_tracks) do
      foreign_key :library_id, :libraries, null: false
      foreign_key :track_id, :tracks, null: false
      primary_key [:library_id, :track_id]
    end

    db.create_table?(:library_playlists) do
      foreign_key :library_id, :libraries, null: false
      foreign_key :playlist_id, :playlists, null: false
      primary_key [:library_id, :playlist_id]
    end
    
    # Authentication data
    
    db.create_table?(:auth_tokens) do
      primary_key :id
      foreign_key :service_id, :services, null: false
      String :access_token, null: false
      String :refresh_token, null: true
      String :token_type, null: true # e.g. Bearer
      DateTime :expires_at, null: true
    end

    return db
  end
end
