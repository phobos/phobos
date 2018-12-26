# frozen_string_literal: true

module Phobos
  module Actions
    class BatchMessage
      attr_accessor :key, :partition, :offset, :payload

      def initialize(key:, partition:, offset:, payload:)
        @key = key
        @partition = partition
        @offset = offset
        @payload = payload
      end

      def ==(other)
        [:key, :partition, :offset, :payload].all? do |s|
          send(s) == other.send(s)
        end
      end
    end

    class ProcessMessageBatch < ProcessMessage
      def initialize(listener:, batch:, metadata:)
        @listener = listener
        @batch = batch
        @metadata = metadata.merge(
          retry_count: 0
        )
      end

      def execute
        payloads = @batch.messages.map do |message|
          BatchMessage.new(
            key: message.key,
            partition: message.partition,
            offset: message.offset,
            payload: force_encoding(message.value)
          )
        end

        begin
          process_batch(payloads)
        rescue StandardError => e
          handle_error(e)
          retry
        end
      end

      private

      def process_batch(payloads)
        handler = @listener.handler_class.new

        preprocessed_payloads = before_consume(handler, payloads)
        consume_block = proc { handler.consume_batch(preprocessed_payloads, @metadata) }

        handler.around_consume_batch(preprocessed_payloads, @metadata, &consume_block)
      end

      def before_consume(handler, payloads)
        handler.before_consume_batch(payloads, @metadata)
      end
    end
  end
end
