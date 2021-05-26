# frozen_string_literal: true

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
require 'phobos/constants'
require 'phobos/log'
require 'phobos/instrumentation'
require 'phobos/errors'
require 'phobos/listener'
require 'phobos/actions/process_batch'
require 'phobos/actions/process_message'
require 'phobos/actions/process_batch_inline'
require 'phobos/producer'
require 'phobos/handler'
require 'phobos/batch_handler'
require 'phobos/echo_handler'
require 'phobos/executor'

Thread.abort_on_exception = true

Logging.init :debug, :info, :warn, :error, :fatal

# Monkey patch to fix this issue: https://github.com/zendesk/ruby-kafka/pull/732
module Logging
  # :nodoc:
  class Logger
    # :nodoc:
    def formatter=(*args); end

    # :nodoc:
    def push_tags(*args); end

    # :nodoc:
    def pop_tags(*args); end
  end
end

module Phobos
  class << self
    attr_reader :config, :logger
    attr_accessor :silence_log

    def configure(configuration)
      @config = fetch_configuration(configuration)
      @config.class.send(:define_method, :producer_hash) do
        Phobos.config.producer&.to_hash&.except(:kafka)
      end
      @config.class.send(:define_method, :consumer_hash) do
        Phobos.config.consumer&.to_hash&.except(:kafka)
      end
      @config.listeners ||= []
      configure_logger
    end

    def add_listeners(configuration)
      listeners_config = fetch_configuration(configuration)
      @config.listeners += listeners_config.listeners
    end

    def create_kafka_client(config_key = nil)
      kafka_config = config.kafka.to_hash.merge(logger: @ruby_kafka_logger)

      if config_key
        kafka_config = kafka_config.merge(**config.send(config_key)&.kafka&.to_hash || {})
      end

      Kafka.new(**kafka_config)
    end

    def create_exponential_backoff(backoff_config = nil)
      backoff_config ||= Phobos.config.backoff.to_hash
      min = backoff_config[:min_ms] / 1000.0
      max = backoff_config[:max_ms] / 1000.0
      ExponentialBackoff.new(min, max).tap { |backoff| backoff.randomize_factor = rand }
    end

    def deprecate(message)
      location = caller.find { |line| line !~ %r{/phobos/} }
      warn "DEPRECATION WARNING: #{message}: #{location}"
    end

    # :nodoc:
    def configure_logger
      Logging.backtrace(true)
      Logging.logger.root.level = silence_log ? :fatal : config.logger.level

      configure_ruby_kafka_logger
      configure_phobos_logger

      logger.info do
        Hash(message: 'Phobos configured', env: ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'N/A')
      end
    end

    private

    def fetch_configuration(configuration)
      DeepStruct.new(read_configuration(configuration))
    end

    def read_configuration(configuration)
      return configuration.to_h if configuration.respond_to?(:to_h)

      YAML.safe_load(
        ERB.new(
          File.read(File.expand_path(configuration))
        ).result,
        [Symbol],
        [],
        true
      )
    end

    def configure_phobos_logger
      if config.custom_logger
        @logger = config.custom_logger
      else
        @logger = Logging.logger[self]
        @logger.appenders = logger_appenders
      end
    end

    def configure_ruby_kafka_logger
      if config.custom_kafka_logger
        @ruby_kafka_logger = config.custom_kafka_logger
      elsif config.logger.ruby_kafka
        @ruby_kafka_logger = Logging.logger['RubyKafka']
        @ruby_kafka_logger.appenders = logger_appenders
        @ruby_kafka_logger.level = silence_log ? :fatal : config.logger.ruby_kafka.level
      else
        @ruby_kafka_logger = nil
      end
    end

    def logger_appenders
      appenders = [Logging.appenders.stdout(layout: stdout_layout)]

      if log_file
        FileUtils.mkdir_p(File.dirname(log_file))
        appenders << Logging.appenders.file(log_file, layout: json_layout)
      end

      appenders
    end

    def log_file
      config.logger.file
    end

    def json_layout
      Logging.layouts.json(date_pattern: Constants::LOG_DATE_PATTERN)
    end

    def stdout_layout
      if config.logger.stdout_json == true
        json_layout
      else
        Logging.layouts.pattern(date_pattern: Constants::LOG_DATE_PATTERN)
      end
    end
  end
end
