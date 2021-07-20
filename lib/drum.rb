require 'drum/service/applemusic'
require 'drum/service/mock'
require 'drum/service/stdio'
require 'drum/service/service'
require 'drum/service/spotify'
require 'drum/version'
require 'highline'
require 'thor'

module Drum
  class Error < StandardError; end
  
  # The command line interface for drum.
  class CLI < Thor
    # Sets up the CLI by registering the services.
    def initialize(*args)
      super

      @hl = HighLine.new

      # Set up .drum directory
      @dot_dir = "#{Dir.home}/.drum"
      Dir.mkdir(@dot_dir) unless Dir.exist?(@dot_dir)

      @cache_dir = "#{@dot_dir}/cache"
      Dir.mkdir(@cache_dir) unless Dir.exist?(@cache_dir)

      @services = [
        MockService.new,
        StdioService.new,
        SpotifyService.new(@cache_dir),
        AppleMusicService.new(@cache_dir)
      ].map { |s| [s.name, s] }.to_h
    end

    def self.exit_on_failure?
      true
    end

    no_commands do
      # Performs a block with the given service, if registered.
      #
      # @yield [name, service] The block to run
      # @yieldparam [String] name The name of the service
      # @yieldparam [Service] service The service
      # @param [String] raw_name The name of the service
      def with_service(raw_name)
        name = raw_name.downcase
        service = @services[name]
        unless service.nil?
          yield(name, service)
        else
          raise "Sorry, #{name} is not a valid service! Try one of these: #{@services.keys}"
        end
      end

      # Parses a ref using the registered services.
      #
      # @return [optional, Ref] The ref, if parsed successfully with any of the services
      def parse_ref(raw)
        @services.each_value do |service|
          ref = service.parse_ref(ref)
          unless ref.nil?
            return ref
          end
        end
        return nil
      end

      # Prompts the user for confirmation.
      #
      # @param [String] prompt The message to be displayed
      def confirm(prompt)
        answer = @hl.ask "#{prompt} [y/n]"
        unless answer == 'y'
          puts 'Okay, exiting.'
          exit
        end
      end
    end

    desc 'preview', 'Previews information from an external service (e.g. spotify)'

    # Previews information from an external service.
    #
    # @param [String] raw_name The (raw) name of the service
    def preview(raw_name)
      self.with_service(raw_name) do |name, service|
        puts "Previewing #{name}..."
        service.preview
      end
    end
    
    desc 'cp [SOURCE] [DEST]', 'Copies a playlist from the source to the given destination.'
    method_option :query_features, aliases: '--query-features', desc: 'Queries audio features for each track.'

    # Copies a playlist from the source to the given destination.
    #
    # @param [String] source_ref The source playlist ref.
    # @param [String] dest_ref The destination playlist ref.
    # @return [void]
    def cp(source_ref, dest_ref)
      self.with_service(raw) do |name, service|
        puts "Copying from #{source_ref} to #{dest_ref}..."
        # TODO: Implement this!
      end
    end
  end
end
