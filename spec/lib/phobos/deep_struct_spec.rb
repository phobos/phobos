require 'spec_helper'

RSpec.describe Phobos::DeepStruct do
  let(:example) { {a: 1, b: [2, 3], c: {x: 4, y: 5}, d: [{j: 6}, {j: 7}]} }
  let(:subject) { described_class.extract(example) }

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
end
