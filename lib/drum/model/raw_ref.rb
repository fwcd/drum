module Drum
  # A 'half-parsed' reference to a resource, either a token or
  # something else. The specifics are left to the service-specific
  # Ref-parser.
  #
  # @!attribute raw
  #   @return [String] The raw text (@-stripped, though, if it's a token)
  # @!attribute is_token
  #   @return [Boolean] Whether the ref is a token (i.e. begins with @)
  RawRef = Struct.new(
    :text,
    :is_token,
    keyword_init: true
  ) do
    TOKEN_PREFIX = '@'

    # Parses a RawRef from the given string.
    #
    # @param [String] raw The raw string to be parsed
    # @return [RawRef] The parsed RawRef
    def self.parse(raw)
      if raw.start_with?(TOKEN_PREFIX)
        RawRef.new(text: raw.delete_prefix(TOKEN_PREFIX), is_token: true)
      else
        RawRef.new(text: raw, is_token: false)
      end
    end
  end
end
