require 'phobos/cli/runner'

module Phobos
  module CLI
    class Start
      def initialize(options)
        @config_file = File.expand_path(options[:config])
        @boot_file = File.expand_path(options[:boot])
      end

      def execute
        validate_config_file!
        Phobos.configure(config_file)
        load_boot_file
        validate_listeners!

        Phobos::CLI::Runner.new.run!
      end

      private

      attr_reader :config_file, :boot_file

      def validate_config_file!
        unless File.exist?(config_file)
          Phobos::CLI.logger.error { Hash(message: "Config file not found (#{config_file})") }
          exit(1)
        end
      end

      def validate_listeners!
        Phobos.config.listeners.collect(&:handler).each do |handler_class|
          begin
            handler_class.constantize
          rescue NameError
            Phobos::CLI.logger.error { Hash(message: "Handler '#{handler_class}' not defined") }
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
