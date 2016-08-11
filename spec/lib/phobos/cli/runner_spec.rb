require 'spec_helper'
require 'phobos/cli'

RSpec.describe Phobos::CLI::Runner do
  describe '#run!' do
    before { Phobos.configure(phobos_config_path) }

    it 'starts and stops Phobos::Executor' do
      executor = Phobos::Executor.new
      expect(Phobos::Executor).to receive(:new).and_return(executor)
      expect(executor).to receive(:start)
      expect(executor).to receive(:stop)

      runner = Phobos::CLI::Runner.new
      runner.send(:unblock, Phobos::CLI::Runner::SIGNALS.first)
      runner.run!
    end
  end
end
