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
require 'erb'

require 'phobos/deep_struct'
require 'phobos/version'
require 'phobos/instrumentation'
require 'phobos/errors'
require 'phobos/listener'
require 'phobos/actions/process_batch'
require 'phobos/actions/process_message'
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
      @config = DeepStruct.new(fetch_settings(configuration))
      @config.class.send(:define_method, :producer_hash) { Phobos.config.producer&.to_hash }
      @config.class.send(:define_method, :consumer_hash) { Phobos.config.consumer&.to_hash }
      @config.listeners ||= []
      configure_logger
      logger.info { Hash(message: 'Phobos configured', env: ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'N/A') }
    end

    def add_listeners(listeners_configuration)
      listeners_config = DeepStruct.new(fetch_settings(listeners_configuration))
      @config.listeners += listeners_config.listeners
    end

    def create_kafka_client
      Kafka.new(config.kafka.to_hash.merge(logger: @ruby_kafka_logger))
    end

    def create_exponential_backoff(backoff_config = nil)
      backoff_config ||= Phobos.config.backoff.to_hash
      min = backoff_config[:min_ms] / 1000.0
      max = backoff_config[:max_ms] / 1000.0
      ExponentialBackoff.new(min, max).tap { |backoff| backoff.randomize_factor = rand }
    end

    # :nodoc:
    def configure_logger
      ruby_kafka = config.logger.ruby_kafka

      Logging.backtrace(true)
      Logging.logger.root.level = silence_log ? :fatal : config.logger.level
      appenders = logger_appenders

      @ruby_kafka_logger = nil

      if config.custom_kafka_logger
        @ruby_kafka_logger = config.custom_kafka_logger
      elsif ruby_kafka
        @ruby_kafka_logger = Logging.logger['RubyKafka']
        @ruby_kafka_logger.appenders = appenders
        @ruby_kafka_logger.level = silence_log ? :fatal : ruby_kafka.level
      end

      if config.custom_logger
        @logger = config.custom_logger
      else
        @logger = Logging.logger[self]
        @logger.appenders = appenders
      end
    end

    def logger_appenders
      date_pattern = '%Y-%m-%dT%H:%M:%S:%L%zZ'
      json_layout = Logging.layouts.json(date_pattern: date_pattern)
      log_file = config.logger.file
      stdout_layout = if config.logger.stdout_json == true
                        json_layout
                      else
                        Logging.layouts.pattern(date_pattern: date_pattern)
                      end

      appenders = [Logging.appenders.stdout(layout: stdout_layout)]

      if log_file
        FileUtils.mkdir_p(File.dirname(log_file))
        appenders << Logging.appenders.file(log_file, layout: json_layout)
      end
      appenders
    end

    private

    def fetch_settings(configuration)
      return configuration.to_h if configuration.respond_to?(:to_h)

      YAML.load(ERB.new(File.read(File.expand_path(configuration))).result)
    end
  end
end
