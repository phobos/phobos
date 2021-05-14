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
          topic: message.topic,
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

          handler.around_consume(payload, @metadata) do |around_payload, around_metadata|
            handler.consume(around_payload, around_metadata)
          end
        end
      end
    end
  end
end
