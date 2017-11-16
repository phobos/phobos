require 'spec_helper'
require 'phobos/test/helper'

RSpec.describe Phobos::Test::Helper do
  class TestHandler < Phobos::EchoHandler
    include Phobos::Handler
    CONSUME_VISITED = 'consume was visited'

    def before_consume(payload)
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
  let(:topic) { Phobos::Test::Helper::Topic }
  let(:group_id) { Phobos::Test::Helper::Group }

  describe '#process_message' do
    it 'synchronously runs the necessary steps for consuming a message with no manual setup' do
      expect_any_instance_of(Phobos::Actions::ProcessMessage)
        .to receive(:instrument)
        .with('listener.process_message', Hash)

      process_message(handler: TestHandler, payload: payload)
    end

    it 'calls before_consume' do
      expect_any_instance_of(TestHandler).to receive(:before_consume).with(payload)
      process_message(handler: TestHandler, payload: payload)
    end

    it 'calls consume' do
      expect_any_instance_of(TestHandler).to receive(:consume).with(payload, Hash)
      process_message(handler: TestHandler, payload: payload)
    end

    it 'returns the result of the handler consume method' do
      expect(process_message(handler: TestHandler, payload: payload))
        .to eq TestHandler::CONSUME_VISITED
    end
  end
end
