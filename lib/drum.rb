require 'drum/db'
require 'drum/version'
require 'thor'

module Drum
  class Error < StandardError; end
  
  class CLI < Thor
    def initialize(*args)
      super
      
      db_dir = "#{Dir.home}/.drum"
      Dir.mkdir(db_dir) unless File.exists?(db_dir)
      Drum.setup_db("#{db_dir}/drum.sqlite3")
    end

    def self.exit_on_failure?
      true
    end
    
    desc 'ping', 'Pongs.'
    def ping
      puts 'Pong!'
    end
  end
end
