require 'spec_helper'
require 'phobos/test/helper'

RSpec.describe Phobos::Test::Helper do
  class TestHandler < Phobos::EchoHandler
    include Phobos::Handler
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
  end
end
