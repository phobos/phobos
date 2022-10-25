# frozen_string_literal: true

module Phobos
  module Handler
    # @!visibility private
    def self.included(base)
      base.extend(ClassMethods)
    end

    def consume(_payload, _metadata)
      raise NotImplementedError
    end

    def around_consume(payload, metadata)
      yield payload, metadata
    end

    module ClassMethods
      def start(kafka_client); end

      def stop; end
    end
  end
end
