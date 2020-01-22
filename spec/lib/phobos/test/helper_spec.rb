# frozen_string_literal: true

require 'spec_helper'
require 'phobos/test/helper'

RSpec.describe Phobos::Test::Helper do
  class TestHelperHandler < Phobos::EchoHandler
    include Phobos::Handler
    CONSUME_VISITED = 'consume was visited'

    def before_consume(payload, _metadata)
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
  let(:listener_metadata) { Hash(key: nil, partition: 0, offset: 13, retry_count: 0, headers: {}) }
  let(:topic) { Phobos::Test::Helper::Topic }
  let(:group_id) { Phobos::Test::Helper::Group }

  describe '#process_message' do
    it 'synchronously runs the necessary steps for consuming a message with no manual setup' do
      expect_any_instance_of(Phobos::Actions::ProcessMessage)
        .to receive(:instrument)
        .with('listener.process_message', Hash)

      process_message(handler: TestHelperHandler, payload: payload)
    end

    it 'invokes handler consume with payload and metadata' do
      expect_any_instance_of(TestHelperHandler).to receive(:consume).with(payload, hash_including(metadata))
      process_message(handler: TestHelperHandler, payload: payload, metadata: metadata)
    end

    it 'returns the result of the handler consume method' do
      expect(process_message(handler: TestHelperHandler, payload: payload))
        .to eq TestHelperHandler::CONSUME_VISITED
    end
  end
end
