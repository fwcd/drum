require 'drum/service/applemusic'
require 'drum/service/dummy'
require 'drum/service/service'
require 'drum/service/spotify'
require 'drum/version'
require 'highline'
require 'thor'

module Drum
  class Error < StandardError; end
  
  class CLI < Thor
    default_task :cp

    # Sets up the CLI by registering the services.
    def initialize(*args)
      super

      @hl = HighLine.new

      # Set up .drum directory
      @dot_dir = "#{Dir.home}/.drum"
      Dir.mkdir(@dot_dir) unless Dir.exist?(@dot_dir)

      @cache_dir = "#{@dot_dir}/cache"
      Dir.mkdir(@cache_dir) unless Dir.exist?(@cache_dir)

      @services = {
        'dummy' => DummyService.new,
        'spotify' => SpotifyService.new(@cache_dir),
        'applemusic' => AppleMusicService.new(@cache_dir)
      }
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
      # @param [String] raw The name of the service
      def with_service(raw)
        name = raw.downcase
        service = @services[name]
        unless service.nil?
          yield(name, service)
        else
          raise "Sorry, #{name} is not a valid service! Try one of these: #{@services.keys}"
        end
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
    def preview(raw)
      self.with_service(raw) do |name, service|
        puts "Previewing #{name}..."
        service.preview
      end
    end
    
    desc 'cp', 'Copies a playlist from the source to the given destination.'
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
