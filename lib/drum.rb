require 'drum/db'
require 'drum/services/dummy'
require 'drum/services/service'
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
        'dummy' => Dummy.new
      }
    end

    def self.exit_on_failure?
      true
    end
    
    desc 'pull', 'Fetches a library from an external service (e.g. spotify)'
    def pull(name)
      service = @services[name.downcase]
      unless service.nil?
        puts "Pulling from #{name}..."
        service.pull
      else
        puts "ERROR: Sorry, #{name} is not a valid service! Try one of these: #{@services.keys}"
      end
    end

    desc 'push', 'Uploads a library to an external service (e.g. spotify)'
    def push(name)
      service = @services[name.downcase]
      unless service.nil?
        puts "Pushing to #{name}..."
        service.push
      else
        puts "ERROR: Sorry, #{name} is not a valid service! Try one of these: #{@services.keys}"
      end
    end
  end
end
