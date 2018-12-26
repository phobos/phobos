# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Phobos::BatchHandler do
  class TestIncludeBatchHandler
    include Phobos::BatchHandler
  end

  it 'includes default ".start"' do
    expect { TestIncludeBatchHandler.start(double('Kafka::Client')) }
      .to_not raise_error
  end

  it 'includes default ".stop"' do
    expect { TestIncludeBatchHandler.stop }.to_not raise_error
  end

  it 'includes default "#around_consume_batch"' do
    expect { |block| TestIncludeBatchHandler.new.around_consume_batch('batch', {}, &block) }
      .to yield_with_no_args
  end

  it 'includes default "#before_consume_batch"' do
    expect(TestIncludeBatchHandler.new.before_consume_batch('payloads', {})).to eq('payloads')
  end

  describe '#consume_batch' do
    it 'raises NotImplementedError' do
      expect { TestIncludeBatchHandler.new.consume_batch('', {}) }
        .to raise_error NotImplementedError
    end
  end
end
