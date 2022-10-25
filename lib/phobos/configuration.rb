# frozen_string_literal: true

require 'phobos/deep_struct'

module Phobos
  module Configuration
    # @param configuration
    # @return [void]
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

    # @return [void]
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

      config_erb = ERB.new(File.read(File.expand_path(configuration))).result

      YAML.safe_load(
        config_erb,
        permitted_classes: [Symbol],
        permitted_symbols: [],
        aliases: true
      )
    rescue ArgumentError
      YAML.safe_load(config_erb, [Symbol], [], true)
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
