require 'spec_helper'

RSpec.describe Phobos::Listener do
  include Phobos::Producer

  class TestListenerHandler < Phobos::EchoHandler
    include Phobos::Handler
  end

  class TestListenerHandlerWithProducer < TestListenerHandler
    include Phobos::Producer
  end

  let!(:topic) { random_topic }
  let!(:group_id) { random_group_id }

  let(:handler) { handler_class.new }
  let(:handler_class) { TestListenerHandler }
  let(:max_bytes) { 8192 } # 8 KB
  let(:max_wait_time) { 0.1 }
  let(:min_bytes) { 2 }
  let(:force_encoding) { nil }
  let :hander_config do
    {
      handler: handler_class,
      topic: topic,
      group_id: group_id,
      max_bytes_per_partition: max_bytes,
      start_from_beginning: true,
      max_wait_time: max_wait_time,
      min_bytes: min_bytes,
      force_encoding: force_encoding
    }
  end
  let(:listener) { Phobos::Listener.new(hander_config) }
  let(:thread) do
    Thread.new { listener.start }.tap { |t| t.abort_on_exception = true }
  end

  before do
    create_topic(topic)
    allow(handler_class).to receive(:new).and_return(handler)
  end

  after do
    Timecop.return
    unsubscribe_all
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

    producer.publish(topic, 'message-1')

    wait_for_event('listener.process_message')
    event = events_for('listener.process_message').first
    expect(event.payload).to include(time_elapsed: 0.1)

    wait_for_event('listener.process_batch')
    event = events_for('listener.process_batch').first
    expect(event.payload).to include(time_elapsed: 0.1)

    listener.stop
    wait_for_event('listener.stop')
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

    it 'does not pass min_bytes to consumer' do
      consumer = listener.send(:create_kafka_consumer)
      expect(listener).to receive(:create_kafka_consumer).and_return(consumer)
      expect(consumer).to receive(:each_batch).with(hash_excluding(:min_bytes)).and_call_original

      consume_and_stop
    end
  end

  context 'when max_wait_time is not set' do
    let(:max_wait_time) { nil }

    it 'does not pass max_wait_time to consumer' do
      consumer = listener.send(:create_kafka_consumer)
      expect(listener).to receive(:create_kafka_consumer).and_return(consumer)
      expect(consumer).to receive(:each_batch).with(hash_excluding(:max_wait_time)).and_call_original

      consume_and_stop
    end
  end

  it 'calls handler with message payload, group_id and topic using async producer' do
    subscribe_to(*LISTENER_EVENTS) { thread }
    wait_for_event('listener.start')

    expect(handler)
      .to receive(:consume)
      .with('message-1', hash_including(group_id: group_id, topic: topic, listener_id: listener.id))

    producer.async_publish(topic, 'message-1')
    wait_for_event('listener.process_batch')

    listener.stop
    wait_for_event('listener.stop')

    self.class.producer.async_producer_shutdown
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

    producer.publish(topic, 'message-1')
    wait_for_event('listener.process_batch')

    listener.stop
    wait_for_event('listener.stop')
  end

  it 'aborts retry when handler is shutting down' do
    subscribe_to(*LISTENER_EVENTS) { thread }
    wait_for_event('listener.start')

    # Ensuring the listener will have a high wait
    backoff = Phobos.create_exponential_backoff
    backoff.multiplier = 10
    allow(Phobos).to receive(:create_exponential_backoff).and_return(backoff)

    allow(handler)
      .to receive(:consume)
      .and_raise('handler exception')

    producer.publish(topic, 'message-1')
    wait_for_event('listener.retry_handler_error', amount: 1, ignore_errors: false)

    listener.stop
    wait_for_event('listener.stopping')

    # Something external will manage the listener thread,
    # calling wakeup manually to simulate this entity stop call
    thread.wakeup
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

  it 'calls handler ".around_consume" with message payload, group_id and topic' do
    subscribe_to(*LISTENER_EVENTS) { thread }
    wait_for_event('listener.start')

    expect(handler_class)
      .to receive(:around_consume)
      .with('message-1', hash_including(group_id: group_id, topic: topic, listener_id: listener.id))
      .and_call_original

    producer.publish(topic, 'message-1')
    wait_for_event('listener.process_batch')

    listener.stop
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
    let(:producer_api) { Phobos::Producer::ClassMethods::PublicAPI.new }

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

  describe 'when force_encoding is configured' do
    let(:force_encoding) { 'UTF_8' }

    {
      Encoding::ASCII_8BIT => 'abc'.encode('ASCII-8BIT'),
      Encoding::ISO_8859_1 => "\u00FC".encode('ISO-8859-1')
    }.each do |encoding, original_payload|
      it "converts #{encoding} to the defined format" do
        payload = original_payload.dup
        expect(original_payload.encoding).to eql encoding
        payload.force_encoding(Encoding::UTF_8)

        subscribe_to(*LISTENER_EVENTS) { thread }
        wait_for_event('listener.start')

        expect(handler).to receive(:consume) do |handler_payload, _|
          expect(handler_payload.bytes).to eql original_payload.bytes
          expect(handler_payload.encoding).to_not eql original_payload.encoding
          expect(handler_payload.encoding).to eql Encoding::UTF_8
        end

        producer.publish(topic, original_payload)
        wait_for_event('listener.process_batch', show_events_on_error: true)

        listener.stop
        wait_for_event('listener.stop')
      end
    end
  end

  def consume_and_stop
    subscribe_to(*LISTENER_EVENTS) { thread }
    wait_for_event('listener.start')

    producer.publish(topic, 'message-1')
    wait_for_event('listener.process_batch')

    listener.stop
    wait_for_event('listener.stop')
  end
end
