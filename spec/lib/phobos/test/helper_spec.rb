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
  let(:metadata) { 'bar' }

  describe '#process_message' do
    it 'creates dummy listener instance for the given handler' do
      process_message(handler: TestHandler, payload: payload, metadata: metadata)
    end

    it 'creates a ProcessMessage instance and invokes execute' do
      process_message(handler: TestHandler, payload: payload, metadata: metadata)
    end
  end
end
