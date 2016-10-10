require 'spec_helper'

RSpec.describe Phobos do
  describe '.configure' do
    it 'creates the configuration obj' do
      Phobos.instance_variable_set(:@config, nil)
      Phobos.configure(phobos_config_path)
      expect(Phobos.config).to_not be_nil
      expect(Phobos.config.kafka).to_not be_nil
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
        expect(Kafka)
          .to receive(:new)
          .with(hash_including(Phobos.config.kafka.to_hash.merge(logger: instance_of(Logging::Logger))))

        Phobos.create_kafka_client
      end
    end
  end

  describe '.create_exponential_backoff' do
    it 'creates a configured ExponentialBackoff' do
      expect(Phobos.create_exponential_backoff).to be_a(ExponentialBackoff)
    end
  end

  describe '.logger' do
    before do
      STDOUT.sync = true
      Phobos.silence_log = false
    end

    context 'without a file configured' do
      it 'writes only to STDOUT' do
        Phobos.config.logger.file = nil
        expect { Phobos.configure_logger }.to_not raise_error

        output = capture(:stdout) { Phobos.logger.info('log-to-stdout') }
        expect(output).to eql output
      end
    end

    context 'with "config.logger.file" defined' do
      it 'writes to the logger file' do
        Phobos.config.logger.file = 'spec/spec.log'
        expect { Phobos.configure_logger }.to_not raise_error

        Phobos.logger.info('log-to-file')
        expect(File.read('spec/spec.log')).to match /log-to-file/
        File.delete(Phobos.config.logger.file)
      end
    end
  end
end
