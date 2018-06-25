# frozen_string_literal: true

module Phobos
  module Handler
    def self.included(base)
      base.extend(ClassMethods)
    end

    def before_consume(payload)
      payload
    end

    def consume(_payload, _metadata)
      raise NotImplementedError
    end

    module ClassMethods
      def start(kafka_client); end

      def stop; end

      def around_consume(_payload, _metadata)
        yield
      end
    end
  end
end
