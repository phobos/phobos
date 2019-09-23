# frozen_string_literal: true

module Phobos
  class BatchMessage
    attr_accessor :key, :partition, :offset, :payload, :headers

    def initialize(key:, partition:, offset:, payload:, headers:)
      @key = key
      @partition = partition
      @offset = offset
      @payload = payload
      @headers = headers
    end

    def ==(other)
      [:key, :partition, :offset, :payload, :headers].all? do |s|
        public_send(s) == other.public_send(s)
      end
    end
  end
end
