module Phobos
  module Actions
    class ProcessMessage
      include Phobos::Instrumentation

      def initialize(listener:, message:, listener_metadata:, encoding:)
        @listener = listener
        @message = message
        @listener_metadata = listener_metadata
        @encoding = encoding
      end

      def execute
        metadata = @listener_metadata.merge(
          key: @message.key,
          partition: @message.partition,
          offset: @message.offset,
          retry_count: 0
        )

        backoff = @listener.create_exponential_backoff
        payload = force_encoding(@message.value)

        begin
          decoded_payload = @listener.handler_class.new.before_consume(payload)
          @listener.handler_class.around_consume(decoded_payload, metadata) do
            @listener.handler_class.new.consume(decoded_payload, metadata)
          end
        rescue => e
          retry_count = metadata[:retry_count]
          interval = backoff.interval_at(retry_count).round(2)

          error = {
            waiting_time: interval,
            exception_class: e.class.name,
            exception_message: e.message,
            backtrace: e.backtrace
          }

          instrument('listener.retry_handler_error', error.merge(metadata)) do
            Phobos.logger.error do
              { message: "error processing message, waiting #{interval}s" }.merge(error).merge(metadata)
            end

            sleep interval
            metadata.merge!(retry_count: retry_count + 1)
          end

          raise Phobos::AbortError if @listener.should_stop?
          retry
        end
      end

      private

      def force_encoding(value)
        @encoding ? value.force_encoding(@encoding) : value
      end
    end
  end
end
