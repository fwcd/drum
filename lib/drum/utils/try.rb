module Drum
  module Try
    # A lightweight variant of rails' try that only supports
    # blocks (the other variants are already handled more
    # elegantly using &.).
    #
    # @yield [value] The block to run if not nil
    # @yieldparam [Object] value The non-nil value
    # @return [Object, nil] Either the mapped self or nil
    def try
      if self.nil?
        nil
      else
        yield self
      end
    end
  end
end

class Object
  include Drum::Try
end
