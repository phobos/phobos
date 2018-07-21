require 'spec_helper'
require 'phobos/test/helper'

RSpec.describe Phobos::Test::Helper do
  class TestHandler < Phobos::EchoHandler
    include Phobos::Handler
    CONSUME_VISITED = 'consume was visited'

    def before_consume(payload, metadata)
      payload
    end

    def consume(_payload, _metadata)
      CONSUME_VISITED
    end
  end

  before :each do
    extend Phobos::Test::Helper
  end

  let(:payload) { 'foo' }
  let(:metadata) { Hash(foo: 'bar') }
  let(:listener_metadata) { Hash(key: nil, partition: 0, offset: 13, retry_count: 0) }
  let(:topic) { Phobos::Test::Helper::Topic }
  let(:group_id) { Phobos::Test::Helper::Group }

  describe '#process_message' do
    it 'synchronously runs the necessary steps for consuming a message with no manual setup' do
      expect_any_instance_of(Phobos::Actions::ProcessMessage)
        .to receive(:instrument)
        .with('listener.process_message', Hash)

      process_message(handler: TestHandler, payload: payload)
    end

    it 'invokes handler before_consume with payload' do
      expect_any_instance_of(TestHandler).to receive(:before_consume).with(payload, listener_metadata)
      process_message(handler: TestHandler, payload: payload)
    end

    it 'invokes handler consume with payload and metadata' do
      expect_any_instance_of(TestHandler).to receive(:consume).with(payload, hash_including(metadata))
      process_message(handler: TestHandler, payload: payload, metadata: metadata)
    end

    it 'returns the result of the handler consume method' do
      expect(process_message(handler: TestHandler, payload: payload))
        .to eq TestHandler::CONSUME_VISITED
    end
  end
end
