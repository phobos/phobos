# frozen_string_literal: true

require 'phobos/processor'

module Phobos
  module Actions
    class ProcessMessage
      include Phobos::Processor

      attr_reader :metadata

      def initialize(listener:, message:, listener_metadata:)
        @listener = listener
        @message = message
        @metadata = listener_metadata.merge(
          key: message.key,
          partition: message.partition,
          offset: message.offset,
          retry_count: 0,
          headers: message.headers
        )
      end

      def execute
        payload = force_encoding(@message.value)

        begin
          process_message(payload)
        rescue StandardError => e
          handle_error(e, 'listener.retry_handler_error',
                       "error processing message, waiting #{backoff_interval}s")
          retry
        end
      end

      private

      def process_message(payload)
        instrument('listener.process_message', @metadata) do
          handler = @listener.handler_class.new

          preprocessed_payload = before_consume(handler, payload)
          consume_block = proc { handler.consume(preprocessed_payload, @metadata) }

          if @listener.handler_class.respond_to?(:around_consume)
            # around_consume class method implementation
            Phobos.deprecate('around_consume has been moved to instance method, please update '\
                             'your consumer. This will not be backwards compatible in the future.')
            @listener.handler_class.around_consume(preprocessed_payload, @metadata, &consume_block)
          else
            # around_consume instance method implementation
            handler.around_consume(preprocessed_payload, @metadata, &consume_block)
          end
        end
      end

      def before_consume(handler, payload)
        handler.before_consume(payload, @metadata)
      rescue ArgumentError
        Phobos.deprecate('before_consume now expects metadata as second argument, please update '\
                         'your consumer. This will not be backwards compatible in the future.')

        handler.before_consume(payload)
      end
    end
  end
end
