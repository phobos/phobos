# frozen_string_literal: true

require 'spec_helper'
require 'phobos/cli'

RSpec.describe Phobos::CLI::Start do
  describe '#execute' do
    it 'validates config file' do
      start = Phobos::CLI::Start.new(config: 'invalid/path', boot: 'phobos_boot.rb')
      expect { start.execute }.to raise_error SystemExit
    end

    context 'when called with `skip_config` option not passed' do
      let(:start) { Phobos::CLI::Start.new(config: phobos_config_path, boot: 'phobos_boot.rb') }

      it 'calls Phobos.configure with config file' do
        allow(Phobos::CLI::Runner).to receive(:new).and_return(double('Phobos::CLI::Runner', run!: true))
        expect(Phobos).to receive(:configure).with(phobos_config_path).and_call_original
        expect { start.execute }.to_not raise_error
      end
    end

    context 'when called with `skip_config` option set to true' do
      let(:start) { Phobos::CLI::Start.new(config: phobos_config_path, boot: 'phobos_boot.rb', skip_config: true) }

      it 'does not call Phobos.configure' do
        allow(Phobos::CLI::Runner).to receive(:new).and_return(double('Phobos::CLI::Runner', run!: true))
        expect(Phobos).to_not receive(:configure)
        expect { start.execute }.to_not raise_error
      end
    end

    context 'delivery option' do
      before do
        allow(Phobos::CLI::Runner).to receive(:new).and_return(double('Phobos::CLI::Runner', run!: true))
      end

      it 'works with batch' do
        start = Phobos::CLI::Start.new(config: 'spec/fixtures/batch_listener.yml', boot: 'phobos_boot.rb')
        expect { start.execute }.to_not raise_error
      end

      it 'works with message' do
        start = Phobos::CLI::Start.new(config: 'spec/fixtures/message_listener.yml', boot: 'phobos_boot.rb')
        expect { start.execute }.to_not raise_error
      end

      it 'works with no delivery option' do
        start = Phobos::CLI::Start.new(config: 'spec/fixtures/no_delivery_option.yml', boot: 'phobos_boot.rb')
        expect { start.execute }.to_not raise_error
      end

      it 'fails with invalid option' do
        start = Phobos::CLI::Start.new(config: 'spec/fixtures/invalid_delivery_option.yml', boot: 'phobos_boot.rb')
        expect { start.execute }.to raise_error SystemExit
      end
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

    context 'when given a listeners file' do
      let(:start) { Phobos::CLI::Start.new(config: phobos_config_path, boot: 'phobos_boot.rb', listeners: 'spec/fixtures/extra_listeners.yml') }

      it 'calls Phobos.add_listeners with listeners file' do
        allow(Phobos::CLI::Runner).to receive(:new).and_return(double('Phobos::CLI::Runner', run!: true))
        expect { start.execute }.to_not raise_error
      end
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
