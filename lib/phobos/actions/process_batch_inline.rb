# frozen_string_literal: true

require 'phobos/batch_message'
require 'phobos/processor'

module Phobos
  module Actions
    class ProcessBatchInline
      include Phobos::Processor

      attr_reader :metadata

      def initialize(listener:, batch:, metadata:)
        @listener = listener
        @batch = batch
        @listener = listener
        @batch = batch
        @metadata = metadata.merge(
          batch_size: batch.messages.count,
          partition: batch.partition,
          offset_lag: batch.offset_lag,
          retry_count: 0
        )
      end

      def execute
        payloads = @batch.messages.map do |message|
          Phobos::BatchMessage.new(
            key: message.key,
            partition: message.partition,
            offset: message.offset,
            payload: force_encoding(message.value)
          )
        end

        begin
          process_batch(payloads)
        rescue StandardError => e
          handle_error(e, 'listener.retry_handler_error_batch',
                       "error processing inline batch, waiting #{backoff_interval}s")
          retry
        end
      end

      private

      def process_batch(payloads)
        instrument('listener.process_batch_inline', @metadata) do |_metadata|
          handler = @listener.handler_class.new

          preprocessed_payloads = handler.before_consume_batch(payloads, @metadata)
          consume_block = proc { handler.consume_batch(preprocessed_payloads, @metadata) }

          handler.around_consume_batch(preprocessed_payloads, @metadata, &consume_block)
        end
      end
    end
  end
end
