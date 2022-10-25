# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Phobos::Listener do
  include Phobos::Producer

  class TestListenerHandler < Phobos::EchoHandler
    include Phobos::Handler
  end

  class TestListenerHandlerWithProducer < TestListenerHandler
    include Phobos::Producer
  end

  class TestBatchListenerHandler
    include Phobos::BatchHandler
    def consume_batch(payloads, metadata)
    end
  end

  let!(:topic) { random_topic }
  let!(:group_id) { random_group_id }

  let(:handler) { handler_class.new }
  let(:handler_class) { TestListenerHandler }
  let(:max_bytes) { 8192 } # 8 KB
  let(:max_wait_time) { 0.1 }
  let(:min_bytes) { 2 }
  let(:force_encoding) { nil }
  let(:listener_backoff) { nil }
  let(:session_timeout) { nil }
  let(:offset_commit_interval) { nil }
  let(:offset_commit_threshold) { nil }
  let(:heartbeat_interval) { nil }
  let(:offset_retention_time) { nil }
  let(:delivery) { 'batch' }
  let :handler_config do
    {
      handler: handler_class,
      topic: topic,
      group_id: group_id,
      max_bytes_per_partition: max_bytes,
      start_from_beginning: true,
      max_wait_time: max_wait_time,
      min_bytes: min_bytes,
      force_encoding: force_encoding,
      backoff: listener_backoff,
      offset_commit_interval: offset_commit_interval,
      offset_commit_threshold: offset_commit_threshold,
      offset_retention_time: offset_retention_time,
      session_timeout: session_timeout,
      heartbeat_interval: heartbeat_interval,
      delivery: delivery
    }
  end
  let(:listener) { Phobos::Listener.new(**handler_config) }
  let(:thread) do
    Thread.new { listener.start }.tap { |t| t.abort_on_exception = true }
  end
  let(:exception_thread) do
    Thread.new { expect { listener.start }.to raise_error(Kafka::ProcessingError) }
  end

  before do
    create_topic(topic)
    allow(handler_class).to receive(:new).and_return(handler)
  end

  after do
    Timecop.return
    unsubscribe_all
  end

  context 'consuming in batches' do
    before do
      expect_any_instance_of(Kafka::Consumer)
        .to receive(:each_batch).and_call_original
    end

    it 'calls handler with message payload, group_id and topic' do
      now = Time.now.utc
      Timecop.freeze(now)

      subscribe_to(*LISTENER_EVENTS) { thread }
      wait_for_event('listener.start')

      expect(handler)
        .to receive(:consume)
          .with('message-1', hash_including(group_id: group_id, topic: topic, listener_id: listener.id))
          .once { Timecop.freeze(now + 0.1) }

      producer.publish(topic: topic, payload: 'message-1')

      wait_for_event('listener.process_message')
      event = events_for('listener.process_message').first
      expect(event.duration.round).to eq 100

      wait_for_event('listener.process_batch')
      event = events_for('listener.process_batch').first
      expect(event.duration.round).to eq 100
      expect(event.payload[:batch_size]).to eq(1)

      listener.stop
      wait_for_event('listener.stop')
    end

    it 'calls Phobos::Actions::ProcessBatch with the fetched Kafka batch' do
      subscribe_to(*LISTENER_EVENTS) { thread }
      wait_for_event('listener.start')

      expect(Phobos::Actions::ProcessBatch)
        .to receive(:new)
        .with(
          listener: listener,
          batch: Kafka::FetchedBatch,
          listener_metadata: hash_including(group_id: group_id, topic: topic, listener_id: listener.id)
        )
        .and_call_original

      producer.async_publish(topic: topic, payload: 'message-1')
      wait_for_event('listener.process_batch')

      listener.stop
      wait_for_event('listener.stop')

      self.class.producer.async_producer_shutdown
    end

    context 'inline_batch delivery' do
      let(:delivery) { 'inline_batch' }
      let(:handler_class) { TestBatchListenerHandler }
      it 'calls Phobos::Actions::ProcessBatchInline for inline_batch delivery' do
        subscribe_to(*LISTENER_EVENTS) { thread }
        wait_for_event('listener.start')

        expect(Phobos::Actions::ProcessBatchInline)
          .to receive(:new)
          .with(
            listener: listener,
            batch: Kafka::FetchedBatch,
            metadata: hash_including(group_id: group_id, topic: topic, listener_id: listener.id),
          )
          .and_call_original

        producer.async_publish(topic: topic, payload: 'message-1')
        wait_for_event('listener.process_batch_inline')

        listener.stop
        wait_for_event('listener.stop')

        self.class.producer.async_producer_shutdown
      end
    end

  end

  context 'consuming individual messages' do
    let(:delivery) { 'message' }

    before do
      expect_any_instance_of(Kafka::Consumer)
        .to receive(:each_message).and_call_original
    end

    it 'calls handler with message payload, group_id and topic' do
      now = Time.now.utc
      Timecop.freeze(now)

      subscribe_to(*LISTENER_EVENTS) { thread }
      wait_for_event('listener.start')

      expect(handler)
        .to receive(:consume)
          .with('message-1', hash_including(group_id: group_id, topic: topic, listener_id: listener.id))
          .once { Timecop.freeze(now + 0.1) }

      producer.publish(topic: topic, payload: 'message-1')

      wait_for_event('listener.process_message')
      event = events_for('listener.process_message').first
      expect(event.duration.round).to eq 100
      expect(event.payload[:batch_size]).to be_nil

      listener.stop
      wait_for_event('listener.stop')
    end

    it 'calls Phobos::Actions::ProcessMessage with the fetched Kafka message' do
      subscribe_to(*LISTENER_EVENTS) { thread }
      wait_for_event('listener.start')

      expect(Phobos::Actions::ProcessMessage)
        .to receive(:new)
        .with(
          listener: listener,
          message: Kafka::FetchedMessage,
          listener_metadata: hash_including(group_id: group_id, topic: topic, listener_id: listener.id)
        )
        .and_call_original

      producer.async_publish(topic: topic, payload: 'message-1')
      wait_for_event('listener.process_message')

      listener.stop
      wait_for_event('listener.stop')

      self.class.producer.async_producer_shutdown
    end
  end

  it 'calls consumer with max_wait_time and min_bytes' do
    consumer = listener.send(:create_kafka_consumer)
    expect(listener).to receive(:create_kafka_consumer).and_return(consumer)
    expect(consumer).to receive(:each_batch).with(
      hash_including(max_wait_time: max_wait_time, min_bytes: min_bytes)
    ).and_call_original

    consume_and_stop
  end

  context 'when min_bytes is not set' do
    let(:min_bytes) { nil }
    let(:consumer) { listener.send(:create_kafka_consumer) }

    before do
      expect(listener).to receive(:create_kafka_consumer).and_return(consumer)
    end

    context 'batches' do
      let(:delivery) { 'batch' }

      it 'does not pass min_bytes to consumer' do
        expect(consumer).to receive(:each_batch).with(hash_excluding(:min_bytes)).and_call_original
        consume_and_stop
      end
    end

    context 'individual messages' do
      let(:delivery) { 'message' }

      it 'does not pass min_bytes to consumer' do
        expect(consumer).to receive(:each_message).with(hash_excluding(:min_bytes)).and_call_original
        consume_and_stop
      end
    end
  end

  context 'when max_wait_time is not set' do
    let(:max_wait_time) { nil }
    let(:consumer) { listener.send(:create_kafka_consumer) }

    before do
      expect(listener).to receive(:create_kafka_consumer).and_return(consumer)
    end

    context 'batches' do
      let(:delivery) { 'batch' }

      it 'does not pass max_wait_time to consumer' do
        expect(consumer).to receive(:each_batch).with(hash_excluding(:max_wait_time)).and_call_original
        consume_and_stop
      end
    end

    context 'individual messages' do
      let(:delivery) { 'message' }

      it 'does not pass max_wait_time to consumer' do
        expect(consumer).to receive(:each_message).with(hash_excluding(:max_wait_time)).and_call_original
        consume_and_stop
      end
    end
  end

  context 'backoff' do
    it 'uses the default backoff settings specified in Phobos.config.backoff' do
      backoff = listener.create_exponential_backoff
      expect(backoff.instance_variable_get(:@minimal_interval)).to eq(Phobos.config.backoff.min_ms / 1000.0)
      expect(backoff.instance_variable_get(:@maximum_elapsed_time)).to eq(Phobos.config.backoff.max_ms / 1000.0)
    end

    context 'when custom backoff is set' do
      let(:listener_backoff) do
        { min_ms: 1_234_000, max_ms: 5_678_000 }
      end

      it 'uses the custom backoff' do
        backoff = listener.create_exponential_backoff
        expect(backoff.instance_variable_get(:@minimal_interval)).to eq(1234)
        expect(backoff.instance_variable_get(:@maximum_elapsed_time)).to eq(5678)
      end
    end
  end

  context 'kafka consumer opts' do
    let(:default_consumer_opts) { Phobos.config.consumer_hash.merge(group_id: group_id) }

    it 'uses the consumer defined options' do
      expect_any_instance_of(Kafka::Client)
        .to receive(:consumer)
        .with(default_consumer_opts)
        .once
        .and_call_original

      subscribe_to(*LISTENER_EVENTS) { thread }
      wait_for_event('listener.start')
    end

    describe 'when custom options are set' do
      let(:session_timeout) { 60 }
      let(:offset_retention_time) { 3600 }
      let(:heartbeat_interval) { 20 }
      let(:offset_commit_interval) { 20 }
      let(:offset_commit_threshold) { 3 }
      let(:kafka_consumer_opts) do
        default_consumer_opts.merge(
          session_timeout: session_timeout,
          offset_retention_time: offset_retention_time,
          offset_commit_interval: offset_commit_interval,
          offset_commit_threshold: offset_commit_threshold,
          heartbeat_interval: heartbeat_interval
        )
      end

      it 'uses the custom options' do
        expect_any_instance_of(Kafka::Client)
          .to receive(:consumer)
          .with(kafka_consumer_opts)
          .once
          .and_call_original

        subscribe_to(*LISTENER_EVENTS) { thread }
        wait_for_event('listener.start')
      end
    end
  end

  it 'retries failed messages' do
    subscribe_to(*LISTENER_EVENTS) { thread }
    wait_for_event('listener.start')

    expect(handler)
      .to receive(:consume)
      .with('message-1', hash_including(retry_count: kind_of(Numeric)))
      .and_raise('handler exception')

    expect(handler)
      .to receive(:consume)
      .with('message-1', hash_including(retry_count: kind_of(Numeric)))

    producer.publish(topic: topic, payload: 'message-1')
    wait_for_event('listener.process_batch')

    listener.stop
    wait_for_event('listener.stop')
  end

  it 'aborts retry when handler is shutting down' do
    subscribe_to(*LISTENER_EVENTS) { exception_thread }
    wait_for_event('listener.start')

    # Ensuring the listener will have a high wait
    backoff = Phobos.create_exponential_backoff
    backoff.multiplier = 10
    allow(listener).to receive(:create_exponential_backoff).and_return(backoff)

    allow(handler)
      .to receive(:consume)
      .and_raise('handler exception')

    producer.publish(topic: topic, payload: 'message-1')
    wait_for_event('listener.retry_handler_error', amount: 1, ignore_errors: false)

    listener.stop
    wait_for_event('listener.stopping')

    # Something external will manage the listener thread,
    # calling wakeup manually to simulate this entity stop call
    exception_thread.wakeup
    wait_for_event('listener.retry_aborted')
    wait_for_event('listener.stop')
    expect(events_for('listener.retry_aborted').size).to eql 1
  end

  it 'calls handler ".start" with kafka_client' do
    expect(handler_class)
      .to receive(:start)
      .once
      .with(an_instance_of(Kafka::Client))

    subscribe_to(*LISTENER_EVENTS) { thread }
    wait_for_event('listener.start_handler')
    wait_for_event('listener.start')

    listener.stop
    wait_for_event('listener.stop')
  end

  it 'calls handler ".stop" when stopping' do
    expect(handler_class)
      .to receive(:stop)
      .once

    subscribe_to(*LISTENER_EVENTS) { thread }
    wait_for_event('listener.start')

    listener.stop
    wait_for_event('listener.stop_handler')
    wait_for_event('listener.stop')
  end

  it 'consumes several messages' do
    producer_batch_size = 500
    total_to_publish = 2_000

    (total_to_publish / producer_batch_size).times do
      messages = Array.new(producer_batch_size) do |i|
        padded_number = i.to_s.rjust(total_to_publish.to_s.length, '0')
        { topic: topic, payload: "message-#{padded_number}", key: i.to_s }
      end

      producer.publish_list(messages)
    end

    subscribe_to(*LISTENER_EVENTS) { thread }
    wait_for_event('listener.start')
    wait_for_event('listener.process_message', amount: total_to_publish)

    listener.stop
    wait_for_event('listener.stop')
  end

  describe 'when the handler includes the producer module' do
    let(:handler_class) { TestListenerHandlerWithProducer }
    let(:producer_api) { Phobos::Producer::ClassMethods::PublicAPI.new(handler_class) }

    before do
      allow(TestListenerHandlerWithProducer)
        .to receive(:producer)
        .and_return(producer_api)
    end

    it 'automatically configures producer with the listener client' do
      expect(Phobos)
        .to receive(:create_kafka_client)
        .once
        .and_call_original

      expect(producer_api)
        .to receive(:configure_kafka_client)
        .with(an_instance_of(Kafka::Client))
        .and_call_original

      # Called with nil when is shutting down
      expect(producer_api)
        .to receive(:configure_kafka_client)
        .with(nil)
        .and_call_original

      subscribe_to(*LISTENER_EVENTS) { thread }
      wait_for_event('listener.start')

      listener.stop
      wait_for_event('listener.stop')
    end

    it 'calls async producer shutdown' do
      expect(producer_api)
        .to receive(:async_producer_shutdown)
        .at_least(:once)
        .and_call_original

      subscribe_to(*LISTENER_EVENTS) { thread }
      wait_for_event('listener.start')

      listener.stop
      wait_for_event('listener.stop')
    end
  end

  def consume_and_stop
    subscribe_to(*LISTENER_EVENTS) { thread }
    wait_for_event('listener.start')

    producer.publish(topic: topic, payload: 'message-1')
    wait_for_event('listener.process_message')

    listener.stop
    wait_for_event('listener.stop')
  end
end
