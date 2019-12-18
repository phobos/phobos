# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Phobos::Producer do
  class TestProducer1
    include Phobos::Producer
  end

  before do
    TestProducer1.producer.configure_kafka_client(nil)
    allow(Phobos::Producer::ClassMethods::PublicAPI).to receive(:new).and_return(public_api)
  end

  after { TestProducer1.producer.configure_kafka_client(nil) }
  subject { TestProducer1.new }
  let(:internal_params) { Phobos::Producer::ClassMethods::PublicAPI::INTERNAL_PRODUCER_PARAMS }
  let(:public_api) { Phobos::Producer::ClassMethods::PublicAPI.new }

  describe '#publish' do
    it 'publishes a single message using "publish_list" when called with positional arguments' do
      expect(TestProducer1.producer)
        .to receive(:publish_list)
        .with([{ topic: 'topic', payload: 'message', key: 'key', partition_key: nil, headers: {}}])

      subject.producer.publish('topic', 'message', 'key')
    end

    it 'logs a deprecation message when called with positional arguments' do
      expect(Phobos).to receive(:deprecate).with(
        /The `publish` method should now receive keyword arguments rather than positional ones/
      )

      subject.producer.publish('topic', 'message', 'key')
    end

    it 'publishes a single message using "publish_list" when called with keyword arguments' do
      expect(TestProducer1.producer)
        .to receive(:publish_list)
        .with([{ topic: 'topic', payload: 'message', key: 'key', partition_key: 'partition_key', headers: { foo: 'bar', fizz: 'buzz' } }])

      subject.producer.publish(topic: 'topic', payload: 'message', key: 'key', partition_key: 'partition_key', foo: 'bar', fizz: 'buzz')
    end

    it 'raises an error if any of the required arguments is not provided' do
      expect { subject.producer.publish }.to raise_error(described_class::PublicAPI::MissingRequiredArgumentsError)
    end
  end

  describe '#async_publish' do
    it 'publishes a single message using "async_publish" when called with positional arguments' do
      expect(TestProducer1.producer)
        .to receive(:async_publish_list)
        .with([{ topic: 'topic', payload: 'message', key: 'key', partition_key: nil, headers: { foo: 'bar', fizz: 'buzz' } }])

      TestProducer1.producer.create_async_producer
      subject.producer.async_publish('topic', 'message', 'key', nil, foo: 'bar', fizz: 'buzz')
    end

    it 'logs a deprecation message when called with positional arguments' do
      expect(Phobos).to receive(:deprecate).with(
        /The `async_publish` method should now receive keyword arguments rather than positional ones/
      )

      subject.producer.async_publish('topic', 'message', 'key')
    end

    it 'publishes a single message using "async_publish" when called with keyword arguments' do
      expect(TestProducer1.producer)
        .to receive(:async_publish_list)
        .with([{ topic: 'topic', payload: 'message', key: 'key', partition_key: 'partition_key', headers: { foo: 'bar' } }])

      TestProducer1.producer.create_async_producer
      subject.producer.async_publish(topic: 'topic', payload: 'message', key: 'key', partition_key: 'partition_key', headers: { foo: 'bar' })
    end

    it 'raises an error if any of the required arguments is not provided' do
      expect { subject.producer.async_publish }.to raise_error(described_class::PublicAPI::MissingRequiredArgumentsError)
    end
  end

  describe '#publish_list' do
    describe 'with a configured client' do
      let(:kafka_client) { double('Kafka::Client', producer: true, close: true) }
      let(:producer) { double('Kafka::RegularProducer', produce: true, deliver_messages: true, shutdown: true) }

      before do
        TestProducer1.producer.configure_kafka_client(kafka_client)
        expect(Phobos).to_not receive(:create_kafka_client)
      end

      context 'without cached producer' do
        it 'publishes and delivers a list of messages' do
          expect(kafka_client)
            .to receive(:producer)
            .with(TestProducer1.producer.regular_configs)
            .and_return(producer)

          expect(producer)
            .to receive(:produce)
            .with('message-1', topic: 'topic-1', key: 'key-1', partition_key: 'part-key-1', headers: nil)

          expect(producer)
            .to receive(:produce)
            .with('message-2', topic: 'topic-2', key: 'key-2', partition_key: 'key-2', headers: { foo: 'bar' })

          expect(producer).to receive(:deliver_messages)
          expect(producer).to receive(:shutdown)
          expect(kafka_client).to_not receive(:close)

          subject.producer.publish_list([
                                          { payload: 'message-1', topic: 'topic-1', key: 'key-1', partition_key: 'part-key-1' },
                                          { payload: 'message-2', topic: 'topic-2', key: 'key-2', headers: { foo: 'bar' } }
                                        ])
        end
      end

      context 'with cached producer' do
        let(:config) { Phobos.config.producer_hash.merge(persistent_connections: true) }
        before(:each) do
          allow(Phobos.config).to receive(:producer_hash).and_return(config)
        end

        it 'publishes and delivers a list of messages twice' do
          allow(producer).to receive(:shutdown)
          expect(kafka_client)
            .to receive(:producer)
            .once
            .with(TestProducer1.producer.regular_configs)
            .and_return(producer)

          expect(producer)
            .to receive(:produce)
            .with('message-1', topic: 'topic-1', key: 'key-1', partition_key: 'part-key-1', headers: nil)

          expect(producer)
            .to receive(:produce)
            .with('message-2', topic: 'topic-2', key: 'key-2', partition_key: 'key-2', headers: { foo: 'bar' })

          expect(producer)
            .to receive(:produce)
            .with('message-3', topic: 'topic-3', key: 'key-3', partition_key: 'part-key-3', headers: nil)

          expect(producer).to receive(:deliver_messages).twice
          expect(producer).to_not have_received(:shutdown)
          expect(kafka_client).to_not receive(:close)

          subject.producer.publish_list([
                                          { payload: 'message-1', topic: 'topic-1', key: 'key-1', partition_key: 'part-key-1' },
                                          { payload: 'message-2', topic: 'topic-2', key: 'key-2', headers: { foo: 'bar' } }
                                        ])
          subject.producer.publish_list([
                                          { payload: 'message-3', topic: 'topic-3', key: 'key-3', partition_key: 'part-key-3' }
                                        ])
          TestProducer1.producer.sync_producer_shutdown
        end
      end

    end

    describe 'without a configured client' do
      let(:kafka_client) { double('Kafka::Client', producer: true, close: true) }
      let(:producer) { double('Kafka::RegularProducer', produce: true, deliver_messages: true) }

      it 'publishes and delivers a list of messages' do
        expect(Phobos).to receive(:create_kafka_client).and_return(kafka_client)

        expect(kafka_client)
          .to receive(:producer)
          .with(TestProducer1.producer.regular_configs)
          .and_return(producer)

        expect(producer)
          .to receive(:produce)
          .with('message-1', topic: 'topic-1', key: 'key-1', partition_key: 'part-key-1', headers: { foo: 'bar' })

        expect(producer)
          .to receive(:produce)
          .with('message-2', topic: 'topic-2', key: 'key-2', partition_key: 'key-2', headers: nil)

        expect(producer).to receive(:deliver_messages)
        expect(producer).to receive(:shutdown)
        expect(kafka_client).to_not receive(:close)

        subject.producer.publish_list([
                                        { payload: 'message-1', topic: 'topic-1', key: 'key-1', partition_key: 'part-key-1', headers: { foo: 'bar' } },
                                        { payload: 'message-2', topic: 'topic-2', key: 'key-2' }
                                      ])
      end
    end
  end

  describe '#async_publish_list' do
    describe 'with a configured async_producer' do
      let(:kafka_client) { double('Kafka::Client', producer: true, close: true) }
      let(:producer) { double('Kafka::AsyncProducer', produce: true, deliver_messages: true) }
      let(:config_hash) { TestProducer1.producer.async_configs }

      before do
        expect(kafka_client)
          .to receive(:async_producer)
          .with(config_hash)
          .and_return(producer)

        expect(producer)
          .to receive(:produce)
          .with('message-1', topic: 'topic-1', key: 'key-1', partition_key: 'key-1', headers: { foo: 'bar' })

        expect(producer)
          .to receive(:produce)
          .with('message-2', topic: 'topic-2', key: 'key-2', partition_key: 'key-2', headers: nil)

        expect(producer).to_not receive(:close)
      end

      describe 'with a delivery interval set' do
        let(:config_hash) do
          Phobos.config.producer_hash.merge(delivery_threshold: 10).
            reject { |k, _| internal_params.include?(k) }
        end

        before do
          allow_any_instance_of(Phobos::Producer::ClassMethods::PublicAPI)
            .to receive(:async_configs).and_return(config_hash)
          expect(producer).to_not receive(:deliver_messages)
        end

        it 'publishes a list of messages without closing the connection' do
          Thread.new do
            TestProducer1.producer.create_async_producer
            TestProducer1.producer.configure_kafka_client(kafka_client)

            subject.producer.async_publish_list([
                                                  { payload: 'message-1', topic: 'topic-1', key: 'key-1', headers: { foo: 'bar' } },
                                                  { payload: 'message-2', topic: 'topic-2', key: 'key-2' }
                                                ])
          end.join
        end
      end

      describe 'with a delivery threshold set' do
        let(:config_hash) do
          Phobos.config.producer_hash.merge(delivery_threshold: 10)
            .reject { |k, _| internal_params.include?(k) }
        end

        before do
          allow_any_instance_of(Phobos::Producer::ClassMethods::PublicAPI)
            .to receive(:async_configs).and_return(config_hash)
          expect(producer).to_not receive(:deliver_messages)
        end

        it 'publishes a list of messages without closing the connection' do
          Thread.new do
            TestProducer1.producer.create_async_producer
            TestProducer1.producer.configure_kafka_client(kafka_client)

            subject.producer.async_publish_list([
                                                  { payload: 'message-1', topic: 'topic-1', key: 'key-1', headers: { foo: 'bar' } },
                                                  { payload: 'message-2', topic: 'topic-2', key: 'key-2' }
                                                ])
          end.join
        end
      end

      describe 'with neither delivery interval or threshold' do
        before do
          expect(producer).to receive(:deliver_messages)
        end

        it 'publishes and delivers a list of messages without closing the connection' do
          Thread.new do
            TestProducer1.producer.create_async_producer
            TestProducer1.producer.configure_kafka_client(kafka_client)

            subject.producer.async_publish_list([
                                                  { payload: 'message-1', topic: 'topic-1', key: 'key-1', headers: { foo: 'bar' } },
                                                  { payload: 'message-2', topic: 'topic-2', key: 'key-2' }
                                                ])
          end.join
        end
      end
    end
  end

  describe '.configure_kafka_client' do
    it 'configures kafka client to the class bound to the current thread' do
      results = Concurrent::Array.new
      latch = Concurrent::CountDownLatch.new(2)

      t1 = Thread.new do
        TestProducer1.producer.configure_kafka_client(:kafka1)
        latch.count_down
        results << TestProducer1.producer.kafka_client
      end

      t2 = Thread.new do
        TestProducer1.producer.configure_kafka_client(:kafka2)
        latch.count_down
        results << TestProducer1.producer.kafka_client
      end

      t3 = Thread.new do
        latch.wait
        expect(TestProducer1.producer.kafka_client).to be_nil
      end

      [t1, t2, t3].map(&:join)
      expect(results.first).to_not eql results.last
    end
  end

  describe '.create_async_producer' do
    let(:kafka_client) { double('Kafka::Client', async_producer: true) }

    describe 'without a kafka_client configured' do
      it 'creates a new client and an async_producer bound to the current thread' do
        config = Phobos.config.producer_hash.reject { |k, _| internal_params.include?(k) }

        expect(kafka_client)
          .to receive(:async_producer)
          .with(config)
          .and_return(:async1, :async2)

        expect(Phobos)
          .to receive(:create_kafka_client)
          .twice
          .and_return(kafka_client)

        results = Concurrent::Array.new
        latch = Concurrent::CountDownLatch.new(2)

        t1 = Thread.new do
          expect(TestProducer1.producer.kafka_client).to be_nil
          expect(TestProducer1.producer.async_producer).to be_nil

          TestProducer1.producer.create_async_producer
          expect(TestProducer1.producer.kafka_client).to eql kafka_client

          latch.count_down
          results << TestProducer1.producer.async_producer
        end

        t2 = Thread.new do
          expect(TestProducer1.producer.kafka_client).to be_nil
          expect(TestProducer1.producer.async_producer).to be_nil

          TestProducer1.producer.create_async_producer
          expect(TestProducer1.producer.kafka_client).to eql kafka_client

          latch.count_down
          results << TestProducer1.producer.async_producer
        end

        t3 = Thread.new do
          latch.wait
          expect(TestProducer1.producer.async_producer).to be_nil
        end

        [t1, t2, t3].map(&:join)
        expect(results.first).to_not eql results.last
      end
    end

    describe 'with a kafka_client configured' do
      it 'uses the configured client' do
        expect(Phobos).to_not receive(:create_kafka_client)
        Thread.new do
          TestProducer1.producer.configure_kafka_client(kafka_client)
          TestProducer1.producer.create_async_producer
        end.join
      end
    end
  end

  describe '.sync_producer_shutdown' do
    let(:producer) { double('Kafka::RegularProducer', produce: true, deliver_messages: true) }
    let(:kafka_client) { double('Kafka::Client', producer: producer, close: true) }
    let(:config) { Phobos.config.producer_hash.merge(persistent_connections: true) }
    before(:each) do
      allow(Phobos.config).to receive(:producer_hash).and_return(config)
    end

    it 'calls shutdown in the configured client and cleans up producer' do
      expect(producer).to receive(:shutdown)

      Thread.new do
        TestProducer1.producer.configure_kafka_client(kafka_client)

        TestProducer1.producer.create_sync_producer
        expect(TestProducer1.producer.sync_producer).to_not be_nil

        TestProducer1.producer.sync_producer_shutdown
        expect(TestProducer1.producer.sync_producer).to be_nil
      end.join
    end
  end

  describe '.async_producer_shutdown' do
    let(:async_producer) { double('Kafka::AsyncProducer', deliver_messages: true, shutdown: true) }
    let(:kafka_client) { double('Kafka::Client', async_producer: async_producer) }

    it 'calls deliver_messages and shutdown in the configured client and cleans up producer' do
      expect(async_producer).to receive(:deliver_messages)
      expect(async_producer).to receive(:shutdown)

      Thread.new do
        TestProducer1.producer.configure_kafka_client(kafka_client)

        TestProducer1.producer.create_async_producer
        expect(TestProducer1.producer.async_producer).to_not be_nil

        TestProducer1.producer.async_producer_shutdown
        expect(TestProducer1.producer.async_producer).to be_nil
      end.join
    end
  end
end
