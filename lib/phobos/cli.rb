require 'thor'
require 'phobos/cli/start'
require 'phobos/cli/init'

module Phobos
  module CLI

    def self.logger
      @logger ||= Logging.logger[self].tap do |l|
        l.appenders = [Logging.appenders.stdout]
      end
    end

    class Commands < Thor
      desc 'start', 'Starts Phobos'
      option :config,
             aliases: ['-c'],
             default: 'config/phobos.yml',
             banner: 'Configuration file'
      option :boot,
             aliases: ['-b'],
             banner: 'File path to load application specific code',
             default: 'phobos_boot.rb'
      def start
        Phobos::CLI::Start.new(options).execute
      end
    end
  end
end
