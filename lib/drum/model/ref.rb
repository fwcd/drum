
module Drum
  # A parsed reference to a resource, usually one or multiple playlists.
  # Can be a folder, a library or the like, located on the local machine
  # or a remote service.
  #
  # See the README for examples.
  #
  # @!attribute [r] service_name
  #   @return [String] The name of the service
  # @!attribute [r] resource_type
  #   @return [Symbol] The type of the resource, may be service-dependent
  # @!attribute [r] resource_location
  #   @return [String] The path/id of the resource, may be service-dependent
  Ref = Struct.new(:service_name, :resource_type, :resource_location) do
    # TODO
  end
end
