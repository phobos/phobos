# frozen_string_literal: true

module Phobos
  class BatchMessage
    attr_accessor :key, :partition, :offset, :payload

    def initialize(key:, partition:, offset:, payload:)
      @key = key
      @partition = partition
      @offset = offset
      @payload = payload
    end

    def ==(other)
      [:key, :partition, :offset, :payload].all? do |s|
        public_send(s) == other.public_send(s)
      end
    end
  end
end
