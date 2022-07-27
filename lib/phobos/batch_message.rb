# frozen_string_literal: true

module Phobos
  class BatchMessage
    # @return
    attr_accessor :key
    # @return [Integer]
    attr_accessor :partition
    # @return [Integer]
    attr_accessor :offset
    # @return
    attr_accessor :payload
    # @return
    attr_accessor :headers

    # @param key
    # @param partition [Integer]
    # @param offset [Integer]
    # @param payload
    # @param headers
    # @return [void]
    def initialize(key:, partition:, offset:, payload:, headers:)
      @key = key
      @partition = partition
      @offset = offset
      @payload = payload
      @headers = headers
    end

    # @param other [Phobos::BatchMessage]
    # @return [Boolean]
    def ==(other)
      [:key, :partition, :offset, :payload, :headers].all? do |s|
        public_send(s) == other.public_send(s)
      end
    end
  end
end
