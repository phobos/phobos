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
          @batch.messages.each do |message|
            Phobos::Actions::ProcessMessage.new(
              listener: @listener,
              message: message,
              listener_metadata: @listener_metadata
            ).execute
            @listener.consumer.trigger_heartbeat
          end
        end
      end
    end
  end
end
