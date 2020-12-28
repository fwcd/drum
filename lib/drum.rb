require 'drum/db'
require 'drum/services/dummy'
require 'drum/services/service'
require 'drum/services/spotify'
require 'drum/version'
require 'thor'

module Drum
  class Error < StandardError; end
  
  class CLI < Thor
    def initialize(*args)
      super
      
      db_dir = "#{Dir.home}/.drum"
      Dir.mkdir(db_dir) unless File.exists?(db_dir)
      @db = Drum.setup_db("sqlite://#{db_dir}/drum.sqlite3")

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
        service.pull(name)
      end
    end

    desc 'push', 'Uploads a library to an external service (e.g. spotify)'
    def push(raw)
      self.with_service(raw) do |name, service|
        puts "Pushing to #{name}..."
        service.push(name)
      end
    end
  end
end
