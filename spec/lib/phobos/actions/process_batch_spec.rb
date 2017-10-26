require 'spec_helper'

RSpec.describe Phobos::Actions::ProcessBatch do
  class TestHandler < Phobos::EchoHandler
    include Phobos::Handler
  end

  let(:listener_metadata) { Hash.new('foo' => 'bar') }
  let(:topic) { 'test-topic' }
  let(:listener) do
    Phobos::Listener.new(
      handler: TestHandler,
      group_id: 'test-group',
      topic: topic
    )
  end
  let(:message1) { Kafka::FetchedMessage.new(value: 'value-1', key: 'key-1', topic: topic, partition: 1, offset: 2) }
  let(:message2) { Kafka::FetchedMessage.new(value: 'value-2', key: 'key-2', topic: topic, partition: 3, offset: 4) }
  let(:messages) { [message1, message2]}
  let(:batch) {
    Kafka::FetchedBatch.new(topic: 'foo', partition: 1, highwater_mark_offset: 1, messages: messages)
  }

  subject { described_class.new(listener: listener, batch: batch, listener_metadata: listener_metadata) }

  it 'calls Phobos::Actions::ProcessMessage with each Kafka message in the batch' do
    expect(Phobos::Actions::ProcessMessage).to receive(:new).with(
      listener: listener,
      message: message1,
      metadata: hash_including(key: 'key-1', partition: 1, offset: 2, retry_count: 0),
      encoding: nil
    ).once.ordered.and_call_original

    expect(Phobos::Actions::ProcessMessage).to receive(:new).with(
      listener: listener,
      message: message2,
      metadata: hash_including(key: 'key-2', partition: 3, offset: 4, retry_count: 0),
      encoding: nil
    ).once.ordered.and_call_original

    subject.execute
  end

  context 'when processing fails' do
    before do
      expect(Phobos::Actions::ProcessMessage).to receive(:new).with(
        listener: listener,
        message: message1,
        metadata: hash_including(key: 'key-1', partition: 1, offset: 2, retry_count: 0),
        encoding: nil
      ).once.ordered.and_call_original

      expect(Phobos::Actions::ProcessMessage).to receive(:new).with(
        listener: listener,
        message: message2,
        metadata: hash_including(key: 'key-2', partition: 3, offset: 4, retry_count: 0),
        encoding: nil
      ).once.ordered.and_raise('processing error')
    end

    it 'it retries failed messages' do
      expect(Phobos::Actions::ProcessMessage).to receive(:new).with(
        listener: listener,
        message: message2,
        metadata: hash_including(key: 'key-2', partition: 3, offset: 4, retry_count: 1),
        encoding: nil
      ).once.ordered.and_call_original

      subject.execute
    end

    context 'when listener is stopping' do
      before do
        allow(listener).to receive(:should_stop?).and_return(true)
      end

      it 'does not retry and raises abort error' do
        expect(Phobos::Actions::ProcessMessage).to_not receive(:new).with(
          listener: listener,
          message: message2,
          metadata: hash_including(key: 'key-2', partition: 3, offset: 4, retry_count: 1),
          encoding: nil
        )

        expect {
          subject.execute
        }.to raise_error(Phobos::AbortError)
      end
    end
  end
end
