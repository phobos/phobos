# frozen_string_literal: true

module Phobos
  module BatchHandler
    def self.included(base)
      base.extend(ClassMethods)
    end

    def before_consume_batch(payloads, _metadata)
      payloads
    end

    def consume_batch(_payloads, _metadata)
      raise NotImplementedError
    end

    def around_consume_batch(_payloads, _metadata)
      yield
    end

    module ClassMethods
      def start(kafka_client); end

      def stop; end
    end
  end
end
