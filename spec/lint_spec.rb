# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'check that the files we have changed have correct syntax' do
  it 'rubocop is satisfied' do
    result = `rubocop --parallel`
    expect(result).to_not match(/Offenses/)
  end
end
