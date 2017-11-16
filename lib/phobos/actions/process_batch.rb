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
        instrument('listener.process_batch', @metadata) do |metadata|
          time_elapsed = measure do
            @batch.messages.each do |message|
              Phobos::Actions::ProcessMessage.new(
                listener: @listener,
                message: message,
                listener_metadata: @listener_metadata
              ).execute
            end
          end

          metadata.merge!(time_elapsed: time_elapsed)
        end
      end
    end
  end
end
