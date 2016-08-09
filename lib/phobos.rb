require 'yaml'

require 'phobos/version'
require 'kafka'
require 'hashie'
require 'logging'
require 'active_support/core_ext/hash/keys'

module Phobos
  class << self
    attr_reader :config, :logger
    attr_accessor :silence_log

    def configure(yml_path)
      ENV['RAILS_ENV'] = ENV['RACK_ENV'] ||= 'development'
      @config = Hashie::Mash.new(YAML.load_file(File.expand_path(yml_path)))
      configure_logger
      logger.info { Hash(message: 'Phobos configured', env: ENV['RACK_ENV']) }
    end

    def create_kafka_client
      Kafka.new(config.kafka.to_hash.symbolize_keys)
    end

    def configure_logger
      date_pattern = '%Y-%m-%dT%H:%M:%S:%L%zZ'
      FileUtils.mkdir_p(File.dirname(config.logger.file))

      Logging.logger.root.appenders = [
        Logging.appenders.stdout(layout: Logging.layouts.pattern(date_pattern: date_pattern)),
        Logging.appenders.file(config.logger.file, layout: Logging.layouts.json(date_pattern: date_pattern))
      ]

      Logging.backtrace true
      Logging.logger.root.level = silence_log ? :fatal : config.logger.level
      @logger = Logging.logger[self]
    end
  end
end
