require 'drum/services/service'
require 'rspotify'

module Drum
  class SpotifyService < Service
    def authenticate
      client_id = ENV['SPOTIFY_CLIENT_ID']
      client_secret = ENV['SPOTIFY_CLIENT_SECRET']
      user = ENV['SPOTIFY_USER']

      unless client_id.nil? || client_secret.nil? || user.nil?
        RSpotify.authenticate(client_id, client_secret)
        @me = RSpotify::User.find(user)
      else
        raise 'Please specify Spotify client ID and secret in your env vars!'
      end
    end

    def preview
      self.authenticate
      puts @me.playlists.map { |p| "Found playlist '#{p.name}'" }
    end
  end
end
