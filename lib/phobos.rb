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

    def configure(configuration)
      ENV['RAILS_ENV'] = ENV['RACK_ENV'] ||= 'development'
      @config = DeepStruct.new(fetch_settings(configuration))
      @config.class.send(:define_method, :producer_hash) { Phobos.config.producer&.to_hash }
      @config.class.send(:define_method, :consumer_hash) { Phobos.config.consumer&.to_hash }
      @config.listeners ||= []
      configure_logger
      logger.info { Hash(message: 'Phobos configured', env: ENV['RACK_ENV']) }
    end

    def add_listeners(listeners_configuration)
      listeners_config = DeepStruct.new(fetch_settings(listeners_configuration))
      @config.listeners += listeners_config.listeners
    end

    def create_kafka_client
      Kafka.new(config.kafka.to_hash.merge(logger: @ruby_kafka_logger))
    end

    def create_exponential_backoff
      min = Phobos.config.backoff.min_ms / 1000.0
      max = Phobos.config.backoff.max_ms / 1000.0
      ExponentialBackoff.new(min, max).tap { |backoff| backoff.randomize_factor = rand }
    end

    def configure_logger
      log_file = config.logger.file
      ruby_kafka = config.logger.ruby_kafka
      date_pattern = '%Y-%m-%dT%H:%M:%S:%L%zZ'
      file_layout = Logging.layouts.json(date_pattern: date_pattern)
      stdout_layout = Logging.layouts.pattern(date_pattern: date_pattern)
      appenders = [Logging.appenders.stdout(layout: stdout_layout)]

      Logging.backtrace(true)
      Logging.logger.root.level = silence_log ? :fatal : config.logger.level

      if log_file
        FileUtils.mkdir_p(File.dirname(log_file))
        appenders << Logging.appenders.file(log_file, layout: file_layout)
      end

      @ruby_kafka_logger = nil

      if ruby_kafka
        @ruby_kafka_logger = Logging.logger['RubyKafka']
        @ruby_kafka_logger.appenders = appenders
        @ruby_kafka_logger.level = silence_log ? :fatal : ruby_kafka.level
      end

      @logger = Logging.logger[self]
      @logger.appenders = appenders
    end

    private

    def fetch_settings(configuration)
      return configuration.to_h if configuration.respond_to?(:to_h)

      YAML.load(ERB.new(File.read(File.expand_path(configuration))).result)
    end
  end
end
