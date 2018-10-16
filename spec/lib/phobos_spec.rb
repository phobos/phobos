# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Phobos do
  describe '.configure' do
    it 'creates the configuration obj' do
      Phobos.instance_variable_set(:@config, nil)
      Phobos.configure(phobos_config_path)
      expect(Phobos.config).to_not be_nil
      expect(Phobos.config.kafka).to_not be_nil
    end

    context 'when using erb syntax in configuration file' do
      it 'parses it correctly' do
        Phobos.instance_variable_set(:@config, nil)
        Phobos.configure('spec/fixtures/phobos_config.yml.erb')

        expect(Phobos.config).to_not be_nil
        expect(Phobos.config.kafka.client_id).to eq('InjectedThroughERB')
      end
    end

    context 'when providing hash with configuration settings' do
      it 'parses it correctly' do
        configuration_settings = {
          kafka: { client_id: 'client_id' },
          logger: { file: 'log/phobos.log' }
        }

        Phobos.instance_variable_set(:@config, nil)
        Phobos.configure(configuration_settings)

        expect(Phobos.config).to_not be_nil
        expect(Phobos.config.kafka.client_id).to eq('client_id')
        expect(Phobos.config.logger.file).to eq('log/phobos.log')
      end

      it 'sets custom loggers' do
        logger = Logger.new(STDOUT)
        kafka_logger = Logger.new(STDOUT)
        configuration_settings = {
          kafka: { client_id: 'client_id' },
          logger: { file: 'log/phobos.log' },
          custom_logger: logger,
          custom_kafka_logger: kafka_logger
        }

        Phobos.instance_variable_set(:@config, nil)
        Phobos.configure(configuration_settings)

        expect(Phobos.config).to_not be_nil
        expect(Phobos.config.kafka.client_id).to eq('client_id')
        expect(Phobos.logger).to eq(logger)

        expect(Kafka).to receive(:new).with(
          client_id: 'client_id',
          logger: kafka_logger
        )
        Phobos.create_kafka_client
      end
    end
  end

  describe '.add_listeners' do
    before { Phobos.configure(phobos_config_path) }
    let(:new_listeners) do
      {
        listeners: [
          {
            handler: 'ListenerTestHandler'
          }
        ]
      }
    end

    it 'adds the given listeners to the previoiusly configured listeners' do
      Phobos.add_listeners(new_listeners)
      # Listener config loaded from phobos main config has not been
      # overwritten:
      expect(Phobos.config.listeners).to include(have_attributes(handler: 'Phobos::EchoHandler'))
      # Listener config passed in has been added:
      expect(Phobos.config.listeners).to include(have_attributes(handler: 'ListenerTestHandler'))
    end
  end

  describe '.create_kafka_client' do
    before { Phobos.configure(phobos_config_path) }

    it 'returns a new kafka client already configured' do
      Phobos.config.logger.ruby_kafka = nil
      Phobos.configure_logger

      expect(Kafka)
        .to receive(:new)
        .with(hash_including(Phobos.config.kafka.to_hash.merge(logger: nil)))
        .and_return(:kafka_client)

      expect(Phobos.create_kafka_client).to eql :kafka_client
    end

    describe 'when "logger.ruby_kafka" is configured' do
      before do
        Phobos.config.logger.ruby_kafka = Phobos::DeepStruct.new(level: 'info')
        Phobos.configure_logger
      end

      it 'configures "logger"' do
        expected = Phobos.config.kafka.to_hash.merge(logger: instance_of(Logging::Logger))
        expect(Kafka)
          .to receive(:new)
          .with(hash_including(expected))

        Phobos.create_kafka_client
      end
    end
  end

  describe '.create_exponential_backoff' do
    it 'creates a configured ExponentialBackoff' do
      expect(Phobos.create_exponential_backoff).to be_a(ExponentialBackoff)
    end

    it 'allows backoff times to be overridden' do
      backoff = Phobos.create_exponential_backoff(min_ms: 1_234_000, max_ms: 5_678_000)
      expect(backoff).to be_a(ExponentialBackoff)
      expect(backoff.instance_variable_get(:@minimal_interval)).to eq(1234)
      expect(backoff.instance_variable_get(:@maximum_elapsed_time)).to eq(5678)
    end
  end

  describe '.logger' do
    let(:stdout_appender) do
      Logging.logger[Phobos].appenders.grep(Logging::Appenders::Stdout).first
    end
    let(:file_appender) do
      Logging.logger[Phobos].appenders.grep(Logging::Appenders::File).first
    end

    it 'outputs human readable format to stdout' do
      expect(stdout_appender.layout).to be_a(Logging::Layouts::Pattern)
      expect(stdout_appender.layout.instance_variable_get(:@pattern)).to eq "[%d] %-5l -- %c : %m\n"
      expect(stdout_appender.layout.instance_variable_get(:@obj_format)).to eq :string
    end

    it 'outputs json format to file' do
      expect(file_appender.layout).to be_a(Logging::Layouts::Parseable)
      expect(file_appender.layout.instance_variable_get(:@style)).to eq :json
    end

    context 'when stdout_json is true' do
      before :each do
        Phobos.config.logger.stdout_json = true
        Phobos.configure_logger
      end

      after :each do
        Phobos.config.logger.stdout_json = false
        Phobos.configure_logger
      end

      it 'outputs json format to stdout' do
        expect(stdout_appender.layout).to be_a(Logging::Layouts::Parseable)
        expect(stdout_appender.layout.instance_variable_get(:@style)).to eq :json
      end

      it 'outputs json format to file' do
        expect(file_appender.layout).to be_a(Logging::Layouts::Parseable)
        expect(file_appender.layout.instance_variable_get(:@style)).to eq :json
      end
    end

    context 'file' do
      before :each do
        allow(Phobos).to receive(:silence_log).and_return(false)
        @old_file = Phobos.config.logger.file
        Phobos.config.logger.file = 'spec/spec.log'
        Phobos.configure_logger
      end

      after :each do
        Phobos.config.logger.file = @old_file
        Phobos.configure_logger
      end

      it 'writes to the logger file' do
        Phobos.logger.info('log-to-file')
        expect(File.read('spec/spec.log')).to match /log-to-file/
        File.delete(Phobos.config.logger.file)
      end
    end
  end
end
