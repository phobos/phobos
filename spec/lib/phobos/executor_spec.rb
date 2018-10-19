# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Phobos::Executor do
  include Phobos::Producer
  MAX_WAIT_TIME = 0.1 # no need to wait for 5 seconds in tests

  class TestHandler1 < Phobos::EchoHandler; end
  class TestHandler2 < Phobos::EchoHandler; end

  let(:executor) { Phobos::Executor.new }
  let(:topics) { [random_topic, random_topic] }

  let(:handler1) { Phobos::EchoHandler.new }
  let(:handler2) { Phobos::EchoHandler.new }
  let(:listeners) do
    [
      Phobos::DeepStruct.new(
        handler: TestHandler1.to_s,
        topic: topics.first,
        group_id: random_group_id,
        start_from_beginning: true,
        max_wait_time: MAX_WAIT_TIME
      ),
      Phobos::DeepStruct.new(
        handler: TestHandler2.to_s,
        topic: topics.last,
        group_id: random_group_id,
        start_from_beginning: true,
        max_wait_time: MAX_WAIT_TIME
      )
    ]
  end

  before do
    topics.each { |topic| create_topic(topic) }
    allow(Phobos.config).to receive(:listeners).and_return(listeners)
    allow(TestHandler1).to receive(:new).and_return(handler1)
    allow(TestHandler2).to receive(:new).and_return(handler2)
  end

  after do
    unsubscribe_all
  end

  it 'starts and stops configured listeners' do
    subscribe_to(*EXECUTOR_EVENTS)
    subscribe_to(*LISTENER_EVENTS) { executor.start }
    wait_for_event('listener.start', amount: 2)

    executor.stop
    wait_for_event('listener.stop', amount: 2)
    wait_for_event('executor.stop')
  end

  it 'reconnects crashed listeners' do
    subscribe_to(*EXECUTOR_EVENTS)
    subscribe_to(*LISTENER_EVENTS) { executor.start }
    wait_for_event('listener.start', amount: 2)

    allow(handler1)
      .to receive(:consume)
      .and_raise(Exception, 'not retryable error')

    # publish event to both consumers
    producer.publish(topics.first, 'message-1')
    producer.publish(topics.last, 'message-1')

    wait_for_event('executor.retry_listener_error', amount_gte: 1)

    wait_for_event('listener.process_message')
    wait_for_event('listener.start', amount_gte: 3)

    executor.stop
    wait_for_event('listener.stop', amount_gte: 2)
    wait_for_event('executor.stop')
  end

  context 'with max concurrency > 1' do
    let(:listeners) do
      [
        Phobos::DeepStruct.new(
          handler: TestHandler1.to_s,
          topic: topics.first,
          group_id: random_group_id,
          start_from_beginning: true,
          max_concurrency: 2,
          max_wait_time: MAX_WAIT_TIME
        ),
        Phobos::DeepStruct.new(
          handler: TestHandler2.to_s,
          topic: topics.last,
          group_id: random_group_id,
          start_from_beginning: true,
          max_wait_time: MAX_WAIT_TIME
        )
      ]
    end

    it 'creates the amount of listeners configured in max_concurrency' do
      subscribe_to(*EXECUTOR_EVENTS)
      subscribe_to(*LISTENER_EVENTS) { executor.start }
      wait_for_event('listener.start', amount: 3, show_events_on_error: true)

      executor.stop
      wait_for_event('listener.stop', amount: 3)
      wait_for_event('executor.stop')
    end
  end

  context 'backoff' do
    let(:listeners) do
      [
        Phobos::DeepStruct.new(
          handler: TestHandler1.to_s,
          topic: topics.first,
          group_id: random_group_id,
          start_from_beginning: true,
          max_wait_time: MAX_WAIT_TIME
        ),
        Phobos::DeepStruct.new(
          handler: TestHandler2.to_s,
          topic: topics.last,
          group_id: random_group_id,
          start_from_beginning: true,
          max_wait_time: MAX_WAIT_TIME,
          backoff: {
            min_ms: 3748,
            max_ms: 5678
          }
        )
      ]
    end

    before do
      allow(TestHandler1).to receive(:new).and_return(handler1)
      allow(TestHandler2).to receive(:new).and_return(handler2)
    end

    it 'uses the default backoff settings specified in Phobos.config.backoff' do
      expect_any_instance_of(ExponentialBackoff).to receive(:interval_at) do |backoff|
        expect(backoff.instance_variable_get(:@maximum_elapsed_time)).to eq(Phobos.config.backoff.max_ms / 1000.0)
        expect(backoff.instance_variable_get(:@minimal_interval)).to eq(Phobos.config.backoff.min_ms / 1000.0)
        1
      end.at_least(:once)

      subscribe_to(*EXECUTOR_EVENTS)
      subscribe_to(*LISTENER_EVENTS) { executor.start }
      wait_for_event('listener.start', amount: 2)

      allow(handler1)
        .to receive(:consume)
        .and_raise(Exception, 'not retryable error')

      producer.publish(topics.first, 'message-1')
      wait_for_event('executor.retry_listener_error', amount: 1)
      wait_for_event('listener.start', amount_gte: 1)

      executor.stop
      wait_for_event('listener.stop', amount_gte: 2)
      wait_for_event('executor.stop')
    end

    context 'with override for specific listener' do
      it 'uses the custom backoff settings' do
        expect_any_instance_of(ExponentialBackoff).to receive(:interval_at) do |backoff|
          expect(backoff.instance_variable_get(:@maximum_elapsed_time)).to eq(5.678)
          expect(backoff.instance_variable_get(:@minimal_interval)).to eq(3.748)
          1
        end.at_least(:once)

        subscribe_to(*EXECUTOR_EVENTS)
        subscribe_to(*LISTENER_EVENTS) { executor.start }
        wait_for_event('listener.start', amount: 2)

        allow(handler2)
          .to receive(:consume)
          .and_raise(Exception, 'not retryable error')

        producer.publish(topics.last, 'message-1')
        wait_for_event('executor.retry_listener_error', amount: 1)
        wait_for_event('listener.start', amount_gte: 1)

        executor.stop
        wait_for_event('listener.stop', amount_gte: 2)
        wait_for_event('executor.stop')
      end
    end
  end
end
