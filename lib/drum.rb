require 'drum/model/raw_ref'
require 'drum/service/applemusic'
require 'drum/service/file'
require 'drum/service/mock'
require 'drum/service/service'
require 'drum/service/spotify'
require 'drum/service/stdio'
require 'drum/utils/log'
require 'drum/version'
require 'highline'
require 'progress_bar'
require 'thor'
require 'yaml'

module Drum
  class Error < StandardError; end
  
  # The command line interface for drum.
  class CLI < Thor
    include Log

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
        AppleMusicService.new(@cache_dir),
        SpotifyService.new(@cache_dir),
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
          log.info 'Okay, exiting.'
          exit
        end
      end
    end

    desc 'show [REF]', 'Preview a playlist in a simplified format'

    # Previews a playlist in a simplified format.
    #
    # @param [String] raw_ref The (raw) playlist ref.
    def show(raw_ref)
      ref = self.parse_ref(raw_ref)

      if ref.nil?
        raise "Could not parse ref: #{raw_ref}"
      end

      self.with_service(ref.service_name) do |name, service|
        playlists = service.download(ref)
        
        playlists.each do |playlist|
          log.all({
            'name' => playlist.name,
            'description' => playlist&.description,
            'tracks' => playlist.tracks.each_with_index.map do |track, i|
              artists = (track.artist_ids&.filter_map { |id| playlist.artists[id]&.name } || []).join(', ')
              "#{i + 1}. #{artists} - #{track.name}"
            end
          }.compact.to_yaml)
        end
      end
    end
    
    desc 'cp [SOURCE] [DEST]', 'Copy a playlist from the source to the given destination'
    method_option :group_by_author, type: :boolean, default: false, desc: "Whether to prepend the author name to each playlist's path"
    method_option :note_date, type: :boolean, default: false, desc: "Whether to add a small note with the upload date to each description."

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
          log.info "Copying from #{src_name} to #{dest_name}..."

          # TODO: Investigate where to handle merging. Should each service
          #       be responsible for doing so, e.g. should the file service
          #       merge playlists and return the result from 'upload'?

          playlists = src_service.download(src_ref).lazy

          unless playlists.size.nil?
            bar = ProgressBar.new(playlists.size)

            # Redirect log output so the bar stays at the bottom
            log.output = bar.method(:puts)
          end

          # Apply transformations to the downloaded playlists.
          # Note that we use 'map' despite mutating the playlists
          # in-place to preserve laziness in the iteration.

          playlists = playlists.map do |playlist|
            bar&.increment!

            if options[:group_by_author]
              author_name = playlist.author_id.try { |id| playlist.users[id] }&.display_name || 'Other'
              playlist.path.unshift(author_name)
            end

            if options[:note_date]
              unless playlist.description.end_with?("\n") || playlist.description.empty?
                playlist.description += "\n"
              end
              playlist.description += Time.now.strftime("Pushed with Drum on %Y-%m-%d")
            end

            playlist
          end

          dest_service.upload(dest_ref, playlists)
        end
      end
    end

    desc 'rm [REF]', 'Remove a playlist from the corresponding service'

    # Removes a playlist from the corresponding service.
    #
    # @param [String] raw_ref The playlist ref.
    # @return [void]
    def rm(raw_ref)
      ref = self.parse_ref(raw_ref)

      if ref.nil?
        raise "Could not parse ref: #{raw_ref}"
      end

      self.with_service(ref.service_name) do |name, service|
        log.info "Removing from #{name}..."
        service.remove(ref)
      end
    end

    desc 'services', 'List available services'

    # Lists available services.
    #
    # @return [void]
    def services
      log.info @services.each_key.to_a.join("\n")
    end

    map %w[--version -v] => :__print_version
    desc '--version, -v', 'Print the version', hide: true

    # Prints the version.
    #
    # @return [void]
    def __print_version
      log.all VERSION
    end
  end
end
