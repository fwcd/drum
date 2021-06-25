require 'drum/utils/kwstruct'

module Drum
  # A parsed reference to a resource, usually one or multiple playlists.
  # Can be a folder, a library or the like, located on the local machine
  # or a remote service.
  #
  # See the README for examples.
  #
  # @!attribute service_name
  #   @return [String] The name of the service
  # @!attribute resource_type
  #   @return [Symbol] The type of the resource, service-dependent
  # @!attribute resource_location
  #   @return [String] The path/id of the resource, service-dependent
  Ref = Struct.new(:service_name, :resource_type, :resource_location) do
    # TODO
  end
end
