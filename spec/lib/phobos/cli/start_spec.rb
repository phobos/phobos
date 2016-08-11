require 'spec_helper'
require 'phobos/cli'

RSpec.describe Phobos::CLI::Start do
  describe '#execute' do
    it 'validates config file' do
      start = Phobos::CLI::Start.new(config: 'invalid/path', boot: 'phobos_boot.rb')
      expect { start.execute }.to raise_error SystemExit
    end

    it 'calls Phobos.configure with config file' do
      allow(Phobos::CLI::Runner).to receive(:new).and_return(double('Phobos::CLI::Runner', run!: true))
      start = Phobos::CLI::Start.new(config: phobos_config_path, boot: 'phobos_boot.rb')
      expect(Phobos).to receive(:configure).with(phobos_config_path).and_call_original
      expect { start.execute }.to_not raise_error
    end

    it 'validates configured handlers' do
      allow(Phobos::CLI::Runner).to receive(:new).and_return(double('Phobos::CLI::Runner', run!: true))
      start = Phobos::CLI::Start.new(config: 'spec/fixtures/bad_listeners.phobos.config.yml', boot: 'phobos_boot.rb')
      expect { start.execute }.to raise_error SystemExit
    end

    it 'loads boot file' do
      allow(Phobos::CLI::Runner).to receive(:new).and_return(double('Phobos::CLI::Runner', run!: true))
      expect($boot_test_loaded).to be_nil
      start = Phobos::CLI::Start.new(config: phobos_config_path, boot: 'spec/fixtures/boot_test.rb')
      expect { start.execute }.to_not raise_error
      expect($boot_test_loaded).to eql true
    end

    it 'starts Phobos::CLI::Runner' do
      runner = double('Phobos::CLI::Runner', run!: true)
      expect(Phobos::CLI::Runner).to receive(:new).and_return(runner)
      expect(runner).to receive(:run!)

      start = Phobos::CLI::Start.new(config: phobos_config_path, boot: 'phobos_boot.rb')
      expect { start.execute }.to_not raise_error
    end
  end
end
