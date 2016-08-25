require 'ostruct'
require 'securerandom'
require 'yaml'

require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/inflections'
require 'active_support/notifications'
require 'concurrent'
require 'exponential_backoff'
require 'kafka'
require 'logging'

require 'phobos/deep_struct'
require 'phobos/version'
require 'phobos/instrumentation'
require 'phobos/errors'
require 'phobos/listener'
require 'phobos/producer'
require 'phobos/handler'
require 'phobos/echo_handler'
require 'phobos/executor'

Thread.abort_on_exception = true

module Phobos
  class << self
    attr_reader :config, :logger
    attr_accessor :silence_log

    def configure(yml_path)
      ENV['RAILS_ENV'] = ENV['RACK_ENV'] ||= 'development'
      @config = DeepStruct.new(YAML.load_file(File.expand_path(yml_path)))
      @config.class.send(:define_method, :producer_hash) { Phobos.config.producer&.to_h }
      @config.class.send(:define_method, :consumer_hash) { Phobos.config.consumer&.to_h }
      configure_logger
      logger.info { Hash(message: 'Phobos configured', env: ENV['RACK_ENV']) }
    end

    def create_kafka_client
      Kafka.new(config.kafka.to_h)
    end

    def create_exponential_backoff
      min = Phobos.config.backoff.min_ms / 1000.0
      max = Phobos.config.backoff.max_ms / 1000.0
      ExponentialBackoff.new(min, max).tap { |backoff| backoff.randomize_factor = rand }
    end

    def configure_logger
      date_pattern = '%Y-%m-%dT%H:%M:%S:%L%zZ'
      FileUtils.mkdir_p(File.dirname(config.logger.file))

      Logging.backtrace true
      Logging.logger.root.level = silence_log ? :fatal : config.logger.level

      @logger = Logging.logger[self]
      @logger.appenders = [
        Logging.appenders.stdout(layout: Logging.layouts.pattern(date_pattern: date_pattern)),
        Logging.appenders.file(config.logger.file, layout: Logging.layouts.json(date_pattern: date_pattern))
      ]
    end
  end
end
