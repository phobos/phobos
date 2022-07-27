# frozen_string_literal: true

require 'thor'
require 'phobos/cli/start'

module Phobos
  # @!visibility private
  module CLI
    def self.logger
      @logger ||= Logging.logger[self].tap do |l|
        l.appenders = [Logging.appenders.stdout]
      end
    end

    # @!visibility private
    class Commands < Thor
      include Thor::Actions

      map '-v' => :version
      map '--version' => :version

      desc 'version', 'Outputs the version number. Can be used with: phobos -v or phobos --version'
      def version
        puts Phobos::VERSION
      end

      desc 'init', 'Initialize your project with Phobos'
      def init
        copy_file 'config/phobos.yml.example', 'config/phobos.yml'
        create_file 'phobos_boot.rb' do
          <<~EXAMPLE
            # Use this file to load your code
            puts <<~ART
              ______ _           _
              | ___ \\\\ |         | |
              | |_/ / |__   ___ | |__   ___  ___
              |  __/| '_ \\\\ / _ \\\\| '_ \\\\ / _ \\\\/ __|
              | |   | | | | (_) | |_) | (_) \\\\__ \\\\
              \\\\_|   |_| |_|\\\\___/|_.__/ \\\\___/|___/
            ART
            puts "\nphobos_boot.rb - find this file at \#{File.expand_path(__FILE__)}\n\n"
          EXAMPLE
        end
      end

      desc 'start', 'Starts Phobos'
      method_option :config,
                    aliases: ['-c'],
                    default: 'config/phobos.yml',
                    banner: 'Configuration file'
      method_option :boot,
                    aliases: ['-b'],
                    banner: 'File path to load application specific code',
                    default: 'phobos_boot.rb'
      method_option :listeners,
                    aliases: ['-l'],
                    banner: 'Separate listeners config file (optional)'
      method_option :skip_config,
                    default: false,
                    type: :boolean,
                    banner: 'Skip config file'
      def start
        Phobos::CLI::Start.new(options).execute
      end

      def self.source_root
        File.expand_path(File.join(File.dirname(__FILE__), '../..'))
      end
    end
  end
end
