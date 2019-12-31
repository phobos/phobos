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

      def preprocess(payload, handler)
        if handler.respond_to?(:before_consume)
          Phobos.deprecate('before_consume is deprecated and will be removed in 2.0. \
                            Use around_consume and yield payload and metadata objects.')
          begin
            handler.before_consume(payload, @metadata)
          rescue ArgumentError
            handler.before_consume(payload)
          end
        else
          payload
        end
      end

      def consume_block(payload, handler)
        proc { |around_payload, around_metadata|
          if around_payload
            handler.consume(around_payload, around_metadata)
          else
            Phobos.deprecate('Calling around_consume without yielding payload and metadata \
                              is deprecated and will be removed in 2.0.')
            handler.consume(payload, @metadata)
          end
        }
      end

      def process_message(payload)
        instrument('listener.process_message', @metadata) do
          handler = @listener.handler_class.new

          preprocessed_payload = preprocess(payload, handler)
          block = consume_block(preprocessed_payload, handler)

          if @listener.handler_class.respond_to?(:around_consume)
            # around_consume class method implementation
            Phobos.deprecate('around_consume has been moved to instance method, please update '\
                             'your consumer. This will not be backwards compatible in the future.')
            @listener.handler_class.around_consume(preprocessed_payload, @metadata, &block)
          else
            # around_consume instance method implementation
            handler.around_consume(preprocessed_payload, @metadata, &block)
          end
        end
      end
    end
  end
end
