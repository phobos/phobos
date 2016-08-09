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
    it 'returns a new kafka client already configured' do
      Phobos.configure(phobos_config_path)

      expect(Kafka)
        .to receive(:new)
        .with(hash_including(Phobos.config.kafka.to_hash.symbolize_keys))
        .and_return(:kafka_client)

      expect(Phobos.create_kafka_client).to eql :kafka_client
    end
  end
end
