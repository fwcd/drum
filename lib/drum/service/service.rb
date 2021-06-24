class Drum::Service
  # Downloads playlists from this service.
  #
  # @param [String] playlist_ref The playlist reference (see README for examples)
  # @return [Hash] The playlists downloaded
  def download(playlist_ref)
    puts "ERROR: Service cannot download playlists (yet)!"
  end

  # Uploads playlists to this service.
  # 
  # @param [String] playlist_ref The playlist reference (see README for examples)
  # @param [Array<Hash>] playlists The list of playlists to be uploaded
  # @return [void]
  def upload(playlist_ref, playlists)
    puts "ERROR: Service cannot upload playlists (yet)!"
  end
end
