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
        batch = @batch.messages.map { |message| instantiate_batch_message(message) }

        begin
          process_batch(batch)
        rescue StandardError => e
          handle_error(e, 'listener.retry_handler_error_batch',
                       "error processing inline batch, waiting #{backoff_interval}s")
          retry
        end
      end

      private

      def instantiate_batch_message(message)
        Phobos::BatchMessage.new(
          key: message.key,
          partition: message.partition,
          offset: message.offset,
          payload: force_encoding(message.value),
          headers: message.headers
        )
      end

      def process_batch(batch)
        instrument('listener.process_batch_inline', @metadata) do |_metadata|
          handler = @listener.handler_class.new

          preprocessed_batch = handler.before_consume_batch(batch, @metadata)
          consume_block = proc { handler.consume_batch(preprocessed_batch, @metadata) }

          handler.around_consume_batch(preprocessed_batch, @metadata, &consume_block)
        end
      end
    end
  end
end
