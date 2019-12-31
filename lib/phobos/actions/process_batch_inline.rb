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

      def preprocess(batch, handler)
        if handler.respond_to?(:before_consume_batch)
          Phobos.deprecate('before_consume_batch is deprecated and will be removed in 2.0. \
                            Use around_consume_batch and yield payloads and metadata objects.')
          handler.before_consume_batch(batch, @metadata)
        else
          batch
        end
      end

      def process_batch(batch)
        instrument('listener.process_batch_inline', @metadata) do |_metadata|
          handler = @listener.handler_class.new

          preprocessed_batch = preprocess(batch, handler)
          consume_block = proc { |around_batch, around_metadata|
            if around_batch
              handler.consume_batch(around_batch, around_metadata)
            else
              Phobos.deprecate('Calling around_consume_batch without yielding payloads \
                                and metadata is deprecated and will be removed in 2.0.')
              handler.consume_batch(preprocessed_batch, @metadata)
            end
          }

          handler.around_consume_batch(preprocessed_batch, @metadata, &consume_block)
        end
      end
    end
  end
end
