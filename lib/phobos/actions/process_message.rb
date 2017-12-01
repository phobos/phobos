module Phobos
  module Actions
    class ProcessMessage
      include Phobos::Instrumentation

      attr_reader :metadata

      def initialize(listener:, message:, listener_metadata:)
        @listener = listener
        @message = message
        @metadata = listener_metadata.merge(
          key: message.key,
          partition: message.partition,
          offset: message.offset,
          retry_count: 0
        )
      end

      def execute
        backoff = @listener.create_exponential_backoff
        payload = force_encoding(@message.value)

        begin
          process_message(payload)
        rescue => e
          retry_count = @metadata[:retry_count]
          interval = backoff.interval_at(retry_count).round(2)

          error = {
            waiting_time: interval,
            exception_class: e.class.name,
            exception_message: e.message,
            backtrace: e.backtrace
          }

          instrument('listener.retry_handler_error', error.merge(@metadata)) do
            Phobos.logger.error do
              { message: "error processing message, waiting #{interval}s" }.merge(error).merge(@metadata)
            end

            sleep interval
          end

          raise Phobos::AbortError if @listener.should_stop?

          @metadata.merge!(retry_count: retry_count + 1)
          retry
        end
      end

      private

      def force_encoding(value)
        @listener.encoding ? value.force_encoding(@listener.encoding) : value
      end

      def process_message(payload)
        instrument('listener.process_message', @metadata) do
          handler = @listener.handler_class.new
          preprocessed_payload = handler.before_consume(payload)

          @listener.handler_class.around_consume(preprocessed_payload, @metadata) do
            handler.consume(preprocessed_payload, @metadata)
          end
        end
      end
    end
  end
end
