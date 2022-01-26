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
    attr_reader :config, :logger
    attr_accessor :silence_log

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
  end
end
