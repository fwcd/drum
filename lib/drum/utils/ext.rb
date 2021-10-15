module Drum
  module Try
    # A lightweight variant of Rails' try that only supports
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

  module Casings
    # Converts a string to kebab-case.
    #
    # @return [String] The kebabcased version of the string
    def kebabcase
      self.gsub(/([A-Z]+)([A-Z][a-z])/,'\1-\2')
          .gsub(/([a-z\d])([A-Z])/,'\1-\2')
          .gsub(/[\s_\/\-_:\.]+/, '-')
          .downcase
    end

    # Converts a string to ['array', 'case']
    #
    # @return [Array<String>] The arraycased version of the string
    def arraycase
      self.kebabcase
          .split('-')
    end

    # Converts a string to Start Case.
    #
    # @return [String] The startcased version of the string
    def startcase
      self.arraycase
          .map { |s| s.capitalize }
          .join(' ')
    end

    # Converts a string to camelCase.
    #
    # @return [String] The camelcased version of the string
    def camelcase
      self.arraycase
          .each_with_index
          .map { |s, i| if i == 0 then s else s.capitalize end }
          .join
    end

    # Converts a string to PascalCase.
    #
    # @return [String] The pascalcased version of the string
    def pascalcase
      self.arraycase
          .map { |s| s.capitalize }
          .join
    end
  end

  module ToHashById
    # Initializes a hash from the array grouping by ids as keys
    # (which are assumed to be unique).
    #
    # @return [Hash<Object, Object>] The resulting hash
    def to_h_by_id
      self.map { |v| [v.id, v] }.to_h
    end
  end
end

class Object
  include Drum::Try
end

class String
  include Drum::Casings
end

class Array
  include Drum::ToHashById
end
