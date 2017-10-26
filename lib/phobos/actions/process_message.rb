module Phobos
  module Actions
    class ProcessMessage
      def initialize(listener:, message:, metadata:, encoding:)
        @listener = listener
        @message = message
        @metadata = metadata
        @encoding = encoding
      end

      def execute
        payload = force_encoding(@message.value)
        decoded_payload = @listener.handler_class.new.before_consume(payload)
        @listener.handler_class.around_consume(decoded_payload, @metadata) do
          @listener.handler_class.new.consume(decoded_payload, @metadata)
        end
      end

      private

      def force_encoding(value)
        @encoding ? value.force_encoding(@encoding) : value
      end
    end
  end
end
