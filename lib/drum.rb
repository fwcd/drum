require 'drum/db'
require 'drum/web/server'
require 'drum/service/applemusic'
require 'drum/service/dummy'
require 'drum/service/service'
require 'drum/service/spotify'
require 'drum/version'
require 'table_print'
require 'highline'
require 'thor'
require 'git'

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
      Dir.mkdir(@dot_dir) unless File.exists?(@dot_dir)

      db_url_path = "#{@dot_dir}/drum.sqlite3"

      # Fix for Windows
      unless db_url_path.start_with?('/')
        db_url_path.prepend('/')
      end

      # Set up Git repo and database
      @git = Git.init(@dot_dir)
      @git.config('user.name', 'drum')
      @git.config('user.email', '')
      @db = Drum.setup_db("sqlite://#{db_url_path}")
      self.commit_changes

      @services = {
        'dummy' => DummyService.new,
        'spotify' => SpotifyService.new(@db),
        'applemusic' => AppleMusicService.new(@db)
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
    
    desc 'pull', 'Fetches a library from an external service (e.g. spotify)'
    method_option :update_existing, aliases: '--update-existing', desc: 'Updates existing tracks in the database.'
    method_option :query_features, aliases: '--query-features', desc: 'Queries audio features for each track.'
    def pull(raw)
      self.with_service(raw) do |name, service|
        puts "Pulling #{name}..."
        service.pull(options)
        self.commit_changes
      end
    end

    desc 'push', 'Uploads a library to an external service (e.g. spotify)'
    method_option :playlist, aliases: '-p', desc: 'A playlist to pull.'
    def push(raw)
      playlist_id = options[:playlist]
      self.with_service(raw) do |name, service|
        playlists = if playlist_id
          @db[:playlists].where(
            id: playlist_id
          ).to_a
        else
          @db[:playlists].to_a
        end

        if playlists.length > 4
          self.confirm "Are you sure you want to push #{playlists.length} playlists to #{name}? You can specify a single playlist id using the '-p' flag!"
        end

        puts "Pushing #{playlists.length} playlist(s) to #{name}..."
        service.push(playlists, options)
      end
    end

    desc 'playlists', 'Lists the stored playlists'
    def playlists
      tp @db[:library_playlists]
        .left_join(:libraries, id: :library_id)
        .join(:playlists, id: Sequel[:library_playlists][:playlist_id])
        .select(
          :playlist_id,
          Sequel[Sequel[:playlists][:name]].as(:playlist_name),
          Sequel[Sequel[:playlists][:description]].as(:playlist_description),
          Sequel[Sequel[:playlists][:user_id]].as(:playlist_user_id),
          Sequel[Sequel[:libraries][:name]].as(:library_name)
        )
    end

    desc 'tracks', 'Lists the stored tracks'
    method_option :playlist, aliases: '-p', desc: 'A playlist to query.'
    method_option :all, aliases: '-a', desc: 'Whether to query all attributes.'
    def tracks
      playlist_id = options[:playlist]
      if playlist_id
        tracks = @db[:playlist_tracks]
          .join(:tracks, id: :track_id)
          .where(playlist_id: playlist_id)
          .order(:track_index)
        unless options[:all]
          tracks = tracks.select(:track_index, :track_id, :name, :duration_ms, :added_at)
        end
      else
        self.confirm "Are you sure you want to query the entire library? (This could take some time.) You can specify a single playlist id using the '-p' flag!"
        tracks = @db[:tracks]
        unless options[:all]
          tracks = tracks.select(:id, :name, :duration_ms)
        end
      end

      tp tracks
    end

    desc 'serve', 'Serves up a web interface for managing the local library.'
    method_option :port, aliases: '-p', desc: 'The port to run on.'
    def serve
      Drum.run_web_server(@db, options)
    end
  end
end
