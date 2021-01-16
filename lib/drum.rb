require 'drum/db'
require 'drum/services/dummy'
require 'drum/services/service'
require 'drum/services/spotify'
require 'drum/version'
require 'thor'
require 'git'

module Drum
  class Error < StandardError; end
  
  class CLI < Thor
    def initialize(*args)
      super

      # Set up .drum directory
      @dot_dir = "#{Dir.home}/.drum"
      Dir.mkdir(@dot_dir) unless File.exists?(@dot_dir)

      # Set up Git repo and database
      @git = Git.init(@dot_dir)
      @git.config('user.name', 'drum')
      @git.config('user.email', '')
      @db = Drum.setup_db("sqlite://#{@dot_dir}/drum.sqlite3")
      self.commit_changes

      @services = {
        'dummy' => DummyService.new,
        'spotify' => SpotifyService.new(@db)
      }
    end

    def self.exit_on_failure?
      true
    end

    no_commands do
      def with_service(raw)
        name = raw.downcase
        service = @services[name]
        unless service.nil?
          yield(name, service)
        else
          raise "Sorry, #{name} is not a valid service! Try one of these: #{@services.keys}"
        end
      end

      def commit_changes
        # TODO: Make sure that we are on the correct (default?) branch
        begin
          @git.add(all: true)
          @git.commit(Time.now.strftime('Snapshot %Y-%m-%d %H:%M:%S'))
        rescue
          # If repo is in a clean state and no changes were made, ignore
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
    def pull(raw)
      self.with_service(raw) do |name, service|
        puts "Pulling #{name}..."
        service.pull(options)
        self.commit_changes
      end
    end

    desc 'push', 'Uploads a library to an external service (e.g. spotify)'
    def push(raw)
      self.with_service(raw) do |name, service|
        puts "Pushing to #{name}..."
        service.push(options)
      end
    end
  end
end
