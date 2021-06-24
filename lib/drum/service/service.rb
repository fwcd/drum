class Drum::Service
  # Previews a playlist from a service. Usually this is useful
  # for debugging.
  #
  # @param [String] playlist_ref A ref to the playlists to be previewed.
  # @return [void]
  def preview
    puts "ERROR: Service does not support previewing (yet)!"
  end

  # Downloads playlists from this service.
  #
  # @param [String] playlist_ref A ref to the playlists (see README for examples)
  # @return [Hash] The playlists downloaded
  def download(playlist_ref)
    puts "ERROR: Service cannot download playlists (yet)!"
  end

  # Uploads playlists to this service.
  # 
  # @param [String] playlist_ref A ref to the upload location (see README for examples)
  # @param [Array<Hash>] playlists The list of playlists to be uploaded
  # @return [void]
  def upload(playlist_ref, playlists)
    puts "ERROR: Service cannot upload playlists (yet)!"
  end
end
