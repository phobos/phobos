require 'yaml'

require 'phobos/version'
require 'kafka'
require 'hashie'
require 'active_support/core_ext/hash/keys'

module Phobos
  class << self
    attr_reader :config

    def configure(yml_path)
      @config = Hashie::Mash.new(YAML.load_file(File.expand_path(yml_path)))
    end

    def create_kafka_client
      Kafka.new(config.kafka.to_hash.symbolize_keys)
    end
  end
end
