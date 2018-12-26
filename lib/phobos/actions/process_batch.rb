# frozen_string_literal: true

module Phobos
  module Actions
    class ProcessBatch
      include Phobos::Instrumentation

      attr_reader :metadata

      def initialize(listener:, batch:, listener_metadata:)
        @listener = listener
        @batch = batch
        @listener_metadata = listener_metadata
        @metadata = listener_metadata.merge(
          batch_size: batch.messages.count,
          partition: batch.partition,
          offset_lag: batch.offset_lag
        )
      end

      def execute
        instrument('listener.process_batch', @metadata) do |_metadata|
          if @listener.handler_class.method_defined?(:consume_batch)
            process_batch_inline
          else
            process_messages
          end
        end
      end

      def process_messages
        @batch.messages.each do |message|
          Phobos::Actions::ProcessMessage.new(
            listener: @listener,
            message: message,
            listener_metadata: @listener_metadata
          ).execute
        end
      end

      def process_batch_inline
        Phobos::Actions::ProcessMessageBatch.new(
          listener: @listener,
          batch: @batch,
          metadata: @metadata
        ).execute
      end
    end
  end
end
