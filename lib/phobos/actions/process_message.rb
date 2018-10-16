# frozen_string_literal: true

module Phobos
  module Actions
    class ProcessMessage
      MAX_SLEEP_INTERVAL = 3

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
        rescue StandardError => e
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
              { message: "error processing message, waiting #{interval}s" }
                .merge(error)
                .merge(@metadata)
            end

            snooze(interval)
          end

          @metadata[:retry_count] = retry_count + 1

          retry
        end
      end

      def snooze(interval)
        remaining_interval = interval

        @listener.send_heartbeat_if_necessary

        while remaining_interval.positive?
          sleep [remaining_interval, MAX_SLEEP_INTERVAL].min
          remaining_interval -= MAX_SLEEP_INTERVAL
          @listener.send_heartbeat_if_necessary
        end
      end

      private

      def force_encoding(value)
        @listener.encoding ? value&.force_encoding(@listener.encoding) : value
      end

      def process_message(payload)
        instrument('listener.process_message', @metadata) do
          handler = @listener.handler_class.new

          preprocessed_payload =
            begin
              handler.before_consume(payload, @metadata)
            rescue ArgumentError => e
              Phobos.deprecate('before_consume now expects metadata as second argument, '\
                'please update your consumer. This will not be backwards compatible in the future.')
              handler.before_consume(payload)
            end
          consume_block = proc { handler.consume(preprocessed_payload, @metadata) }

          if @listener.handler_class.respond_to?(:around_consume)
            # around_consume class method implementation
            Phobos.deprecate('around_consume has been moved to instance method, '\
              'please update your consumer. This will not be backwards compatible in the future.')
            @listener.handler_class.around_consume(preprocessed_payload, @metadata, &consume_block)
          else
            # around_consume instance method implementation
            handler.around_consume(preprocessed_payload, @metadata, &consume_block)
          end
        end
      end
    end
  end
end
