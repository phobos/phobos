module Phobos
  module Handler
    def self.included(base)
      base.extend(ClassMethods)
    end

    def consume(payload, metadata)
      raise NotImplementedError
    end

    module ClassMethods
      def self.start(kafka_client)
      end

      def self.stop
      end

      def self.around_consume(payload, metadata)
        yield
      end
    end
  end
end
