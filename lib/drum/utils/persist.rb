require 'drum/utils/log'
require 'yaml'

module Drum
  # A wrapper around a hash that stores values persistently in a YAML.
  #
  # @!attribute value
  #  @return [Hash] The wrapped hash
  class PersistentHash
    include Log
    attr_reader :value

    # Creates a new persistent hash.
    #
    # @param [String] file_path The path to the stored YAML file (may be non-existent).
    # @param [Hash] value The initial default value, if the file doesn't exist yet or is malformed
    def initialize(file_path, value={})
      @file_path = file_path
      begin
        self.load
      rescue StandardError => e
        unless e.is_a?(Errno::ENOENT)
          log.warn "Could not load #{file_path}: #{e.inspect}... creating from scratch"
        end
        @value = value
        self.store
      end
    end

    # Loads the hash from the file.
    def load
      @value = YAML.load(File.read(@file_path))
    end

    # Saves the hash to the file.
    def store
      File.write(@file_path, @value.to_yaml)
    end

    # Writes a mapping to the hash and stores it on disk.
    #
    # @param [Object] key The key to use.
    # @param [Object] value The value to map the key to.
    def []=(key, value)
      @value[key] = value
      store
    end

    # Reads a mapping from the hash.
    #
    # @param [Object] key The key to use.
    # @return [Object] The value the key is mapped to.
    def [](key)
      @value[key]
    end
  end
end
