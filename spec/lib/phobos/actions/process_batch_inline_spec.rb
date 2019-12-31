# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Phobos::Actions::ProcessBatchInline do
  class TestBatchHandler
    include Phobos::BatchHandler

    def consume_batch(payloads, metadata)
      Phobos.logger.info { Hash(payloads: payloads).merge(metadata) }
    end
  end

  # for backwards compatibility
  class TestBatchHandler2 < TestBatchHandler

    def around_consume_batch(payloads, metadata)
      yield
    end
  end

  class TestBatchHandler3 < TestBatchHandler

    def before_consume_batch(payloads, metadata)
      payloads
    end

  end

  let(:payload) { 'message-1234' }
  let(:topic) { 'test-topic' }
  let(:message1) do
    Kafka::FetchedMessage.new(
      message: Kafka::Protocol::Record.new(value: 'value-1', key: 'key-1', offset: 2),
      topic: topic,
      partition: 1
    )
  end
  let(:message2) do
    Kafka::FetchedMessage.new(
      message: Kafka::Protocol::Record.new(value: 'value-2', key: 'key-2', offset: 4),
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
  let(:metadata) { Hash(foo: 'bar') }
  let(:listener) do
    Phobos::Listener.new(
      handler: TestBatchHandler,
      group_id: 'test-group',
      topic: topic
    )
  end

  let(:payloads) do
    batch.messages.map do |message|
          Phobos::BatchMessage.new(
            key: message.key,
            partition: message.partition,
            offset: message.offset,
            payload: message.value,
            headers: message.headers
          )
        end
  end

  subject do
    described_class.new(
      listener: listener,
      batch: batch,
      metadata: metadata
    )
  end

  before do
    allow(subject).to receive(:sleep) # Prevent sleeping in tests
    allow(subject).to receive(:force_encoding) { |p| p }
  end

  it 'processes the message by calling around consume, before consume and consume of the handler' do
    expect(subject).to receive(:force_encoding).twice { |p| p }
    expect_any_instance_of(TestBatchHandler).to receive(:around_consume_batch).
      with(payloads, subject.metadata).once.and_call_original
    expect_any_instance_of(TestBatchHandler).to receive(:consume_batch).
      with(payloads, subject.metadata).once.and_call_original

    subject.execute
  end

  context 'deprecated around_consume_batch yielding no arguments' do
    let(:listener) do
      Phobos::Listener.new(
        handler: TestBatchHandler2,
        group_id: 'test-group',
        topic: topic
      )
    end

    it 'supports the method and logs a deprecation message' do
      expect(Phobos).to receive(:deprecate).once
      expect_any_instance_of(TestBatchHandler2).to receive(:around_consume_batch).
        with(payloads, subject.metadata).once.and_call_original
      expect_any_instance_of(TestBatchHandler2).to receive(:consume_batch).
        with(payloads, subject.metadata).once.and_call_original

      subject.execute
    end
  end

  context 'with deprecated before_consume_batch' do
    let(:listener) do
      Phobos::Listener.new(
        handler: TestBatchHandler3,
        group_id: 'test-group',
        topic: topic
      )
    end

    it 'calls before_consume and deprecates' do
      expect_any_instance_of(TestBatchHandler3).to receive(:around_consume_batch).
        with(payloads, subject.metadata).once.and_call_original
      expect(Phobos).to receive(:deprecate).once
      expect_any_instance_of(TestBatchHandler3).to receive(:before_consume_batch).
        with(payloads, subject.metadata).once.and_call_original
      expect_any_instance_of(TestBatchHandler3).to receive(:consume_batch).
        with(payloads, subject.metadata).once.and_call_original

      subject.execute
    end

  end

  context 'when processing fails' do
    before do
      expect(subject)
        .to receive(:process_batch).once.ordered.and_raise('processing error')
    end

    it 'it retries failed messages' do
      expect(subject)
        .to receive(:process_batch).once.ordered.and_raise('processing error')
      expect(subject)
        .to receive(:process_batch).once.ordered.and_call_original

      subject.execute
      expect(subject.metadata[:retry_count]).to eq(2)
    end

    context 'when listener is stopping' do
      before do
        allow(listener).to receive(:should_stop?).and_return(true)
      end

      it 'does not retry and raises abort error' do
        expect(subject).to_not receive(:process_batch)

        expect do
          subject.execute
        end.to raise_error(Phobos::AbortError)

        expect(subject.metadata[:retry_count]).to eq(0)
      end
    end
  end

end
