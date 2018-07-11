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

  let(:payload) { 'message-1234' }
  let(:topic) { 'test-topic' }
  let(:message) do
    Kafka::FetchedMessage.new(
      message: Kafka::Protocol::Message.new(value: payload, key: 'key-1', offset: 2),
      topic: topic,
      partition: 1,
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
      expect_any_instance_of(TestHandler2).to receive(:before_consume).with(payload, subject.metadata).once.and_call_original
      expect_any_instance_of(TestHandler2).to receive(:consume).with(payload, subject.metadata).once.and_call_original

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

    it "passes on messages with no content untouched" do
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

        expect {
          subject.execute
        }.to raise_error(Phobos::AbortError)

        expect(subject.metadata[:retry_count]).to eq(0)
      end
    end
  end
end
