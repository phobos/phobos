# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Phobos::Actions::ProcessMessage do
  class TestHandler < Phobos::EchoHandler
    include Phobos::Handler
  end

  # For backwards compatibility
  class TestHandler2 < Phobos::EchoHandler
    include Phobos::Handler

    def self.around_consume(payload, metadata)
      yield
    end
  end

  class TestHandler3 < Phobos::EchoHandler
    include Phobos::Handler

    def before_consume(payload)
      payload
    end
  end

  let(:payload) { 'message-1234' }
  let(:topic) { 'test-topic' }
  let(:message) do
    Kafka::FetchedMessage.new(
      message: Kafka::Protocol::Message.new(value: payload, key: 'key-1', offset: 2),
      topic: topic,
      partition: 1
    )
  end
  let(:metadata) { Hash(foo: 'bar') }
  let(:listener) do
    Phobos::Listener.new(
      handler: TestHandler,
      group_id: 'test-group',
      topic: topic
    )
  end

  subject do
    described_class.new(
      listener: listener,
      message: message,
      listener_metadata: metadata
    )
  end

  before do
    allow(subject).to receive(:sleep) # Prevent sleeping in tests
  end

  it 'processes the message by calling around consume, before consume and consume of the handler' do
    expect_any_instance_of(TestHandler).to receive(:around_consume).with(payload, subject.metadata).once.and_call_original
    expect_any_instance_of(TestHandler).to receive(:before_consume).with(payload, subject.metadata).once.and_call_original
    expect_any_instance_of(TestHandler).to receive(:consume).with(payload, subject.metadata).once.and_call_original

    subject.execute
  end

  context '.around_consumed defined' do
    let(:listener) do
      Phobos::Listener.new(
        handler: TestHandler2,
        group_id: 'test-group',
        topic: topic
      )
    end

    it 'supports and prefers around_consume if defined as a class method' do
      expect(TestHandler2).to receive(:around_consume).with(payload, subject.metadata).once.and_call_original
      expect(Phobos).to receive(:deprecate).once
      expect_any_instance_of(TestHandler2).to receive(:before_consume).with(payload, subject.metadata).once.and_call_original
      expect_any_instance_of(TestHandler2).to receive(:consume).with(payload, subject.metadata).once.and_call_original

      subject.execute
    end
  end

  context '#before_consume defined with 1 argument' do
    let(:listener) do
      Phobos::Listener.new(
        handler: TestHandler3,
        group_id: 'test-group',
        topic: topic
      )
    end

    it 'supports the method and logs a deprecation message' do
      expect(Phobos).to receive(:deprecate).once
      expect_any_instance_of(TestHandler3).to receive(:around_consume).with(payload, subject.metadata).once.and_call_original
      expect_any_instance_of(TestHandler3).to receive(:before_consume).with(payload).once.and_call_original
      expect_any_instance_of(TestHandler3).to receive(:consume).with(payload, subject.metadata).once.and_call_original

      subject.execute
    end

  end

  context 'with encoding' do
    let(:handler) { TestHandler.new }
    let(:force_encoding) { 'UTF-8' }
    before :each do
      allow(TestHandler).to receive(:new).and_return(handler)
      allow(listener).to receive(:encoding).and_return(force_encoding)
    end

    {
      Encoding::ASCII_8BIT => 'abc'.encode('ASCII-8BIT'),
      Encoding::ISO_8859_1 => "\u00FC".encode('ISO-8859-1')
    }.each do |encoding, original_payload|
      it "converts #{encoding} to the defined format" do
        expect(original_payload.encoding).to eql encoding

        expect(handler).to receive(:consume) do |handler_payload, _|
          expect(handler_payload.bytes).to eql original_payload.bytes
          expect(handler_payload.encoding).to_not eql original_payload.encoding
          expect(handler_payload.encoding).to eql Encoding::UTF_8
        end

        described_class.new(
          listener: listener,
          message: OpenStruct.new(value: original_payload.dup),
          listener_metadata: metadata
        ).execute
      end
    end

    it 'passes on messages with no content untouched' do
      expect(handler).to receive(:consume) do |handler_payload, _|
        expect(handler_payload).to be nil
      end

      described_class.new(
        listener: listener,
        message: OpenStruct.new(value: nil),
        listener_metadata: metadata
      ).execute
    end
  end

  context 'when processing fails' do
    before do
      expect(subject)
        .to receive(:process_message).once.ordered.and_raise('processing error')
    end

    it 'it retries failed messages' do
      expect(subject)
        .to receive(:process_message).once.ordered.and_raise('processing error')
      expect(subject)
        .to receive(:process_message).once.ordered.and_call_original

      subject.execute
      expect(subject.metadata[:retry_count]).to eq(2)
    end

    context 'when listener is stopping' do
      before do
        allow(listener).to receive(:should_stop?).and_return(true)
      end

      it 'does not retry and raises abort error' do
        expect(subject).to_not receive(:process_message)

        expect do
          subject.execute
        end.to raise_error(Phobos::AbortError)

        expect(subject.metadata[:retry_count]).to eq(0)
      end
    end
  end

  describe '#snooze' do
    context 'when interval is 0' do
      let(:interval) { 0 }

      it 'attempts to send a heartbeat' do
        expect(listener).to receive(:send_heartbeat_if_necessary).once
        subject.snooze(interval)
      end

      it 'does not sleep' do
        expect(subject).to receive(:sleep).never
        subject.snooze(interval)
      end
    end

    context 'when interval is less than MAX_SLEEP_INTERVAL' do
      let(:interval) { described_class::MAX_SLEEP_INTERVAL.to_f / 2 }

      it 'attempts to send heartbeats twice' do
        expect(listener).to receive(:send_heartbeat_if_necessary).twice
        subject.snooze(interval)
      end

      it 'sleeps once at the specified interval' do
        expect(subject).to receive(:sleep).with(interval).once
        subject.snooze(interval)
      end
    end

    context 'when interval is MAX_SLEEP_INTERVAL + 1' do
      let(:interval) { described_class::MAX_SLEEP_INTERVAL + 1 }

      it 'attempts to send heartbeats 3 times' do
        expect(listener)
          .to receive(:send_heartbeat_if_necessary)
          .exactly(3).times
        subject.snooze(interval)
      end

      it 'sleeps once for MAX_SLEEP_INTERVAL and once for 1 second' do
        expect(subject).to receive(:sleep).with(described_class::MAX_SLEEP_INTERVAL).ordered.once
        expect(subject).to receive(:sleep).with(1).ordered.once
        expect(subject).to receive(:sleep).ordered.never
        subject.snooze(interval)
      end
    end
  end
end
