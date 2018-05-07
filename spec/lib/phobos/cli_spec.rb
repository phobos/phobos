require 'spec_helper'
require 'phobos/cli'

RSpec.describe Phobos::CLI do

  describe '$ phobos' do
    it 'prints help text' do
      output = capture_stdout { Phobos::CLI::Commands.start([]) }
      expect(output).to include 'help [COMMAND]  # Describe available commands or one...'
    end
  end

  describe '$ phobos start' do
    it 'calls start command with -c flag and defaults -b to "phobos_boot.rb"' do
      expect(Phobos::CLI::Start)
        .to receive(:new)
        .with(hash_including('config' => 'config/phobos.yml', 'boot' => 'phobos_boot.rb'))
        .and_return(double('Phobos::CLI::Start', execute: true))

      args = ['start', '-c', 'config/phobos.yml']
      Phobos::CLI::Commands.start(args)
    end

    it 'accepts optional -b' do
      expect(Phobos::CLI::Start)
        .to receive(:new)
        .with(hash_including('config' => 'config/phobos.yml', 'boot' => 'boot.rb'))
        .and_return(double('Phobos::CLI::Start', execute: true))

      args = ['start', '-c', 'config/phobos.yml', '-b', 'boot.rb']
      Phobos::CLI::Commands.start(args)
    end

    it 'accepts optional -l' do
      expect(Phobos::CLI::Start)
        .to receive(:new)
        .with(hash_including('listeners' => 'config/listeners.yml'))
        .and_return(double('Phobos::CLI::Start', execute: true))

      args = ['start', '-c', 'config/phobos.yml', '-l', 'config/listeners.yml']
      Phobos::CLI::Commands.start(args)
    end
  end

end
