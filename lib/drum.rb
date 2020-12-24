require 'drum/version'
require 'thor'

module Drum
  class Error < StandardError; end
  
  class CLI < Thor
    def self.exit_on_failure?
      true
    end
    
    desc 'ping', 'Pongs.'
    def ping
      puts 'Pong!'
    end
  end
end
