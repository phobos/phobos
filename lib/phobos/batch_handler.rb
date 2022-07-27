# frozen_string_literal: true

module Phobos
  module BatchHandler
    # @!visibility private
    def self.included(base)
      base.extend(ClassMethods)
    end

    # @param _payloads [Array]
    # @param _metadata [Hash<String, Object>]
    # @return [void]
    def consume_batch(_payloads, _metadata)
      raise NotImplementedError
    end

    # @param payloads [Array]
    # @param metadata [Hash<String, Object>]
    # @yield [Array, Hash<String, Object>]
    # @return [void]
    def around_consume_batch(payloads, metadata)
      yield payloads, metadata
    end

    module ClassMethods
      # @param kafka_client
      # @return [void]
      def start(kafka_client); end

      # @return [void]
      def stop; end
    end
  end
end
