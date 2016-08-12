require 'spec_helper'

RSpec.describe Phobos::Executor do
  include Phobos::Producer

  class TestHandler1 < Phobos::EchoHandler; end
  class TestHandler2 < Phobos::EchoHandler; end

  let(:executor) { Phobos::Executor.new }
  let(:topics) { [random_topic, random_topic] }

  let(:handler1) { Phobos::EchoHandler.new }
  let(:handler2) { Phobos::EchoHandler.new }

  let :listeners do
    [
      Hashie::Mash.new(handler: TestHandler1.to_s, topic: topics.first, group_id: random_group_id, start_from_beginning: true),
      Hashie::Mash.new(handler: TestHandler2.to_s, topic: topics.last, group_id: random_group_id, start_from_beginning: true)
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

  it 'disconnects and reconnects crashed listeners' do
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
    wait_for_event('listener.stop', amount_gte: 2)
    wait_for_event('listener.start', amount_gte: 2)

    executor.stop
    wait_for_event('listener.stop', amount_gte: 2)
    wait_for_event('executor.stop')
  end

end
