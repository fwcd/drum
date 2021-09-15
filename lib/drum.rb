require 'drum/model/raw_ref'
require 'drum/service/applemusic'
require 'drum/service/file'
require 'drum/service/mock'
require 'drum/service/service'
require 'drum/service/spotify'
require 'drum/service/stdio'
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
      @dot_dir = Pathname.new(Dir.home) / '.drum'
      @dot_dir.mkdir unless @dot_dir.directory?

      @cache_dir = @dot_dir / 'cache'
      @cache_dir.mkdir unless @cache_dir.directory?

      # Declare services in descending order of parse priority
      @services = [
        MockService.new,
        StdioService.new,
        SpotifyService.new(@cache_dir),
        AppleMusicService.new(@cache_dir),
        # The file service should be last since it may
        # successfully parse refs that overlap with other
        # services.
        FileService.new
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
        if service.nil?
          raise "Sorry, #{name} is not a valid service! Try one of these: #{@services.keys}"
        end
        yield(name, service)
      end

      # Parses a ref using the registered services.
      #
      # @param [String] raw The raw ref to parse
      # @return [optional, Ref] The ref, if parsed successfully with any of the services
      def parse_ref(raw)
        raw_ref = RawRef.parse(raw)
        @services.each_value do |service|
          ref = service.parse_ref(raw_ref)
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
    # @param [String] raw_src_ref The source playlist ref.
    # @param [String] raw_dest_ref The destination playlist ref.
    # @return [void]
    def cp(raw_src_ref, raw_dest_ref)
      src_ref = self.parse_ref(raw_src_ref)
      dest_ref = self.parse_ref(raw_dest_ref)

      if src_ref.nil?
        raise "Could not parse src ref: #{raw_src_ref}"
      end
      if dest_ref.nil?
        raise "Could not parse dest ref: #{raw_dest_ref}"
      end

      self.with_service(src_ref.service_name) do |src_name, src_service|
        self.with_service(dest_ref.service_name) do |dest_name, dest_service|
          puts "Copying from #{src_name} to #{dest_name}..."

          playlists = src_service.download(src_ref)
          updated_playlists = dest_service.upload(dest_ref, playlists)

          unless updated_playlists.nil?
            src_service.upload(src_ref, updated_playlists)
          end
        end
      end
    end
  end
end
