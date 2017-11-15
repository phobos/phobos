require 'phobos/cli/runner'

module Phobos
  module CLI
    class Start
      def initialize(options)
        unless options[:skip_config]
          @config_file = File.expand_path(options[:config])
        end
        @boot_file = File.expand_path(options[:boot])

        if options[:listeners]
          @listeners_file = File.expand_path(options[:listeners])
        end
      end

      def execute
        if config_file
          validate_config_file!
          Phobos.configure(config_file)
        end

        load_boot_file

        if listeners_file
          Phobos.add_listeners(listeners_file)
        end

        validate_listeners!

        Phobos::CLI::Runner.new.run!
      end

      private

      attr_reader :config_file, :boot_file, :listeners_file

      def validate_config_file!
        unless File.exist?(config_file)
          Phobos::CLI.logger.error { Hash(message: "Config file not found (#{config_file})") }
          exit(1)
        end
      end

      def validate_listeners!
        Phobos.config.listeners.each do |listener|
          handler_class = listener.handler

          begin
            handler_class.constantize
          rescue NameError
            Phobos::CLI.logger.error { Hash(message: "Handler '#{handler_class}' not defined") }
            exit(1)
          end

          delivery = listener.delivery
          if delivery.nil?
            Phobos::CLI.logger.warn do
              Hash(message: "Delivery option should be specified, defaulting to 'batch' - specify this option to silence this message")
            end
          elsif !Listener::DELIVERY_OPTS.include?(delivery)
            Phobos::CLI.logger.error do
              Hash(message: "Invalid delivery option '#{delivery}'. Please specify one of: #{Listener::DELIVERY_OPTS.join(', ')}")
            end
            exit(1)
          end
        end
      end

      def load_boot_file
        load(boot_file) if File.exist?(boot_file)
      end
    end
  end
end
