# A wrapper around a music streaming service's API providing methods
# for downloading/uploading playlists.
class Drum::Service
  # The service's internal name used to identify it.
  #
  # @return [String] The internal name of the service.
  def name
    raise "ERROR: Service does not specify a name!"
  end

  # Tries to parse a ref from this service.
  #
  # @param [RawRef] raw_ref The raw reference to be parsed.
  # @return [optional, Ref] The ref, if parsed successfully, otherwise nil
  def parse_ref(raw_ref)
    nil
  end

  # TODO: Update docs to be more general (e.g. ref instead of playlist_ref)

  # Removes playlists from this service.
  #
  # @param [Ref] playlist_ref A ref to the playlists (see README for examples)
  def remove(playlist_ref)
    raise "ERROR: Service '#{self.name}' cannot remove playlists (yet)!"
  end

  # Downloads playlists from this service.
  #
  # @param [Ref] playlist_ref A ref to the playlists (see README for examples)
  # @return [Array<Playlist>] The playlists downloaded
  def download(playlist_ref)
    raise "ERROR: Service '#{self.name}' cannot download playlists (yet)!"
  end

  # Uploads playlists to this service.
  # 
  # @param [Ref] playlist_ref A ref to the upload location (see README for examples)
  # @param [Array<Playlist>, Enumerator<Playlist>] playlists The list of playlists to be uploaded
  def upload(playlist_ref, playlists)
    raise "ERROR: Service '#{self.name}' cannot upload playlists (yet)!"
  end
end
