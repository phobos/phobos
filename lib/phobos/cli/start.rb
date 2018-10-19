# frozen_string_literal: true

require 'phobos/cli/runner'

module Phobos
  module CLI
    class Start
      def initialize(options)
        @config_file = File.expand_path(options[:config]) unless options[:skip_config]
        @boot_file = File.expand_path(options[:boot])

        @listeners_file = File.expand_path(options[:listeners]) if options[:listeners]
      end

      def execute
        load_boot_file

        if config_file
          validate_config_file!
          Phobos.configure(config_file)
        end

        Phobos.add_listeners(listeners_file) if listeners_file

        validate_listeners!

        Phobos::CLI::Runner.new.run!
      end

      private

      attr_reader :config_file, :boot_file, :listeners_file

      def validate_config_file!
        File.exist?(config_file) || error_exit("Config file not found (#{config_file})")
      end

      def validate_listeners!
        Phobos.config.listeners.each do |listener|
          handler = listener.handler

          Object.const_defined?(handler) || error_exit("Handler '#{handler}' not defined")

          delivery = listener.delivery
          if delivery.nil?
            Phobos::CLI.logger.warn do
              Hash(message: "Delivery option should be specified, defaulting to 'batch'"\
                ' - specify this option to silence this message')
            end
          elsif !Listener::DELIVERY_OPTS.include?(delivery)
            error_exit("Invalid delivery option '#{delivery}'. Please specify one of: "\
              "#{Listener::DELIVERY_OPTS.join(', ')}")
          end
        end
      end

      def error_exit(msg)
        Phobos::CLI.logger.error { Hash(message: msg) }
        exit(1)
      end

      def load_boot_file
        load(boot_file) if File.exist?(boot_file)
      end
    end
  end
end
