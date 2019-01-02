# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Phobos::Actions::ProcessBatch do
  class TestHandler < Phobos::EchoHandler
    include Phobos::Handler
  end

  class TestBatchHandler
    include Phobos::BatchHandler
    def consume_batch(payloads, metadata)
      Phobos.logger.info { Hash(payloads: payloads).merge(metadata) }
    end
  end

  let(:listener_metadata) { Hash(foo: 'bar') }
  let(:topic) { 'test-topic' }
  let(:listener) do
    Phobos::Listener.new(
      handler: TestHandler,
      group_id: 'test-group',
      topic: topic
    )
  end
  let(:batch_listener) do
    Phobos::Listener.new(
                      handler: TestBatchHandler,
                      group_id: 'test-group',
                      topic: topic
    )
  end
  let(:message1) do
    Kafka::FetchedMessage.new(
      message: Kafka::Protocol::Message.new(value: 'value-1', key: 'key-1', offset: 2),
      topic: topic,
      partition: 1
    )
  end
  let(:message2) do
    Kafka::FetchedMessage.new(
      message: Kafka::Protocol::Message.new(value: 'value-2', key: 'key-2', offset: 4),
      topic: topic,
      partition: 3
    )
  end
  let(:batch) do
    Kafka::FetchedBatch.new(
      topic: 'foo',
      partition: 1,
      highwater_mark_offset: 1,
      messages: [message1, message2],
      last_offset: 0
    )
  end

  before do
    allow(subject).to receive(:sleep) # Prevent sleeping in tests
  end

  subject { described_class.new(listener: listener, batch: batch, listener_metadata: listener_metadata) }

  it 'calls Phobos::Actions::ProcessMessage with each Kafka message in the batch' do
    expect(Phobos::Actions::ProcessMessage).to receive(:new).with(
      listener: listener,
      message: message1,
      listener_metadata: listener_metadata
    ).once.ordered.and_call_original

    expect(Phobos::Actions::ProcessMessage).to receive(:new).with(
      listener: listener,
      message: message2,
      listener_metadata: listener_metadata
    ).once.ordered.and_call_original

    subject.execute
  end

  context 'batch handling' do
    subject { described_class.new(listener: batch_listener,
                                  batch: batch,
                                  listener_metadata: listener_metadata,
                                  inline: true
                                  ) }

    it 'calls Phobos::Actions::ProcessMessageBatch' do
      metadata = listener_metadata.merge(
          batch_size: batch.messages.count,
          partition: batch.partition,
          offset_lag: batch.offset_lag
        )
      expect(Phobos::Actions::ProcessMessageBatch).to receive(:new).with(
        listener: batch_listener,
        batch: batch,
        metadata: metadata
      ).once.ordered.and_call_original
      subject.execute
    end
  end
end
