require 'spec_helper'
Thread.abort_on_exception = true

RSpec.describe Phobos::Listener do
  include Phobos::Producer

  let!(:topic) { random_topic }
  let!(:group_id) { random_group_id }

  let(:handler_class) { Phobos::EchoHandler }
  let(:handler) { handler_class.new }
  let(:listener) { Phobos::Listener.new(handler_class, topic: topic, group_id: group_id) }

  before do
    create_topic(topic)
    allow(handler_class).to receive(:new).and_return(handler)

    subscribe_to(
      'listener.retry_handler_error',
      'listener.process_message',
      'listener.process_batch',
      'listener.stop',
      'listener.start'
    ) { Thread.new { listener.start } }
    wait_for_event('listener.start')
  end

  after do
    unsubscribe_all
  end

  it 'calls handler with message payload, group_id and topic' do
    expect(handler)
      .to receive(:consume)
      .with('message-1', hash_including(group_id: group_id, topic: topic))

    publish(topic, 'message-1')
    wait_for_event('listener.process_batch')

    listener.stop
    wait_for_event('listener.stop')
  end

  it 'retries failed messages' do
    expect(handler)
      .to receive(:consume)
      .with('message-1', hash_including(retry_count: 0))
      .and_raise('handler exception')

    expect(handler)
      .to receive(:consume)
      .with('message-1', hash_including(retry_count: 1))

    publish(topic, 'message-1')
    wait_for_event('listener.process_batch')

    listener.stop
    wait_for_event('listener.stop')

    expect(events_for('listener.retry_handler_error').size).to eql 1
    expect(events_for('listener.process_message').size).to eql 2
  end
end
