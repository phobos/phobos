require 'spec_helper'

RSpec.describe Phobos::Listener do
  include Phobos::Producer

  let!(:topic) { random_topic }
  let!(:group_id) { random_group_id }

  let(:handler) { handler_class.new }
  let(:handler_class) { Phobos::EchoHandler }
  let(:max_bytes) { 8192 } # 8 KB
  let :hander_config do
    {
      handler: handler_class,
      topic: topic,
      group_id: group_id,
      max_bytes_per_partition: max_bytes,
      start_from_beginning: true
    }
  end
  let(:listener) { Phobos::Listener.new(hander_config) }
  let(:thread) { Thread.new { listener.start } }

  before do
    create_topic(topic)
    allow(handler_class).to receive(:new).and_return(handler)
  end

  after do
    unsubscribe_all
  end

  it 'calls handler with message payload, group_id and topic' do
    subscribe_to(*LISTENER_EVENTS) { thread }
    wait_for_event('listener.start')

    expect(handler)
      .to receive(:consume)
      .with('message-1', hash_including(group_id: group_id, topic: topic, listener_id: listener.id))

    producer.publish(topic, 'message-1')
    wait_for_event('listener.process_batch')

    listener.stop
    wait_for_event('listener.stop')
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

  it 'abort retry when handler is shutting down' do
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
      messages = producer_batch_size.times.map do |i|
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
end
