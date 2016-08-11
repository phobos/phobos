require 'spec_helper'
require 'phobos/cli'

RSpec.describe Phobos::CLI do

  describe '$ phobos' do
    it 'prints help text' do
      output = capture(:stdout) { Phobos::CLI::Commands.start([]) }
      expect(output).to include 'help [COMMAND]  # Describe available commands or one specific command'
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
  end

  describe '$ phobos init' do
    it 'calls init command' do
      expect(Phobos::CLI::Init)
        .to receive(:new)
        .and_return(double('Phobos::CLI::Init', execute: true))

      Phobos::CLI::Commands.start(['init'])
    end
  end

end
