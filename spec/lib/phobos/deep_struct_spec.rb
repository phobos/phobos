# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Phobos::DeepStruct do
  let(:example) do
    {
      a: 1,
      b: [2, 3],
      c: { x: 4, y: 5 },
      d: [{ j: 6 }, { j: 7 }],
      e: [8, { x: 9 }]
    }
  end

  let(:subject) { described_class.new(example) }

  context '.new' do
    it 'hash keys are accessible as method calls' do
      expect(subject.a).to eq(1)
      expect(subject.b).to eq([2, 3])
    end

    it 'deep hash keys are accessible as chained method calls' do
      expect(subject.c.x).to eq(4)
      expect(subject.c.y).to eq(5)
    end

    it 'handles array of hashes' do
      expect(subject.d[0].j).to eq(6)
      expect(subject.d[1].j).to eq(7)
    end

    it 'handles array of mixed types' do
      expect(subject.e[0]).to eq(8)
      expect(subject.e[1].x).to eq(9)
    end
  end

  context '#to_h' do
    it 'renders itself as a hash' do
      expect(subject.to_h).to eq(example)
    end

    it 'returns a copy to avoid side effects' do
      copy = subject.to_h
      copy[:new_key] = 'b'
      expect(subject.new_key).to be_nil
      expect(subject.to_h[:new_key]).to be_nil
    end
  end

  context '#to_hash' do
    it 'renders itself as a hash' do
      expect(subject.to_hash).to eq(example)
    end
  end
end
