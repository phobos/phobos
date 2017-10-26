require 'spec_helper'

RSpec.describe Phobos::Actions::ProcessMessage do
  class TestHandler < Phobos::EchoHandler
    include Phobos::Handler
  end

  let(:payload) { 'message-1234' }
  let(:message) { OpenStruct.new(value: payload) }
  let(:metadata) { Hash.new('foo' => 'bar') }
  let(:listener) do
    Phobos::Listener.new(
      handler: TestHandler,
      group_id: 'test-group',
      topic: 'test-topic'
    )
  end

  subject { described_class.new(listener: listener, message: message, metadata: metadata, encoding: nil) }

  it 'processes the message by calling around consume, before consume and consume of the handler' do
    expect(TestHandler).to receive(:around_consume).with(payload, metadata).once.and_call_original
    expect_any_instance_of(TestHandler).to receive(:before_consume).with(payload).once.and_call_original
    expect_any_instance_of(TestHandler).to receive(:consume).with(payload, metadata).once.and_call_original

    subject.execute
  end

  context 'with encoding' do
    let(:handler) { TestHandler.new }
    let(:force_encoding) { 'UTF-8' }
    before :each do
      allow(TestHandler).to receive(:new).and_return(handler)
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

        described_class.new(listener: listener, message: OpenStruct.new(value: original_payload.dup), metadata: metadata, encoding: force_encoding).execute
      end
    end
  end
end
