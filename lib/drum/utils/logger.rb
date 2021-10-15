require 'logger'

module Drum
  # A simple logging facility.
  #
  # @!attribute level
  #   @return [Logger::Level] The minimum level of messages to be logged
  # @!attribute output
  #   @return [Proc] A function taking a string for outputting a message
  class Logger
    module Level
      ERROR = 2
      WARN = 1
      INFO = 0
      DEBUG = -1
      TRACE = -2
    end

    attr_accessor :level
    attr_accessor :output

    # Creates a new logger with the given level.
    #
    # @param [Logger::Level] level The minimum level of messages to be logged.
    # @param [Proc] output A function taking a string for outputting a message.
    def initialize(level: Level::INFO, output: method(:puts))
      self.level = level
      self.output = output
    end

    # Logs a message at the given level.
    #
    # @param [Logger::Level] level The level to log the message at.
    # @param [String] msg The message to log.
    def log(level, msg)
      if level >= self.level
        self.output.(msg)
      end
    end

    # Logs a message at the ERROR level.
    #
    # @param [String] msg The message to log.
    def error(msg)
      self.log(Level::ERROR, msg)
    end

    # Logs a message at the WARN level.
    #
    # @param [String] msg The message to log.
    def warn(msg)
      self.log(Level::WARN, msg)
    end

    # Logs a message at the INFO level.
    #
    # @param [String] msg The message to log.
    def info(msg)
      self.log(Level::INFO, msg)
    end

    # Logs a message at the DEBUG level.
    #
    # @param [String] msg The message to log.
    def debug(msg)
      self.log(Level::DEBUG, msg)
    end

    # Logs a message at the TRACE level.
    #
    # @param [String] msg The message to log.
    def trace(msg)
      self.log(Level::TRACE, msg)
    end
  end

  # The global logger.
  log = Logger.new
end
