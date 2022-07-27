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

require 'phobos/configuration'
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
# @!visibility private
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
  extend Configuration
  class << self
    # @return [Phobos::DeepStruct]
    attr_reader :config
    # @return [Logger]
    attr_reader :logger
    # @return [Boolean]
    attr_accessor :silence_log

    # @param configuration [Hash<String, Object>]
    # @return [void]
    def add_listeners(configuration)
      listeners_config = fetch_configuration(configuration)
      @config.listeners += listeners_config.listeners
    end

    # @param config_key [String]
    def create_kafka_client(config_key = nil)
      kafka_config = config.kafka.to_hash.merge(logger: @ruby_kafka_logger)

      if config_key
        kafka_config = kafka_config.merge(**config.send(config_key)&.kafka&.to_hash || {})
      end

      Kafka.new(**kafka_config)
    end

    # @param backoff_config [Hash<Symbol, Integer>]
    def create_exponential_backoff(backoff_config = nil)
      backoff_config ||= Phobos.config.backoff.to_hash
      min = backoff_config[:min_ms] / 1000.0
      max = backoff_config[:max_ms] / 1000.0
      ExponentialBackoff.new(min, max).tap { |backoff| backoff.randomize_factor = rand }
    end

    # @param message [String]
    # @return [void]
    def deprecate(message)
      location = caller.find { |line| line !~ %r{/phobos/} }
      warn "DEPRECATION WARNING: #{message}: #{location}"
    end
  end
end
