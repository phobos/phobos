module Phobos
  module Actions
    class ProcessBatch
      include Phobos::Instrumentation

      def initialize(listener:, batch:, listener_metadata:)
        @listener = listener
        @batch = batch
        @listener_metadata = listener_metadata
      end

      def execute
        @batch.messages.each do |message|
          metadata = @listener_metadata.merge(
            key: message.key,
            partition: message.partition,
            offset: message.offset,
            retry_count: 0
          )

          instrument('listener.process_message', metadata) do |metadata|
            time_elapsed = measure do
              Phobos::Actions::ProcessMessage.new(
                listener: @listener,
                message: message,
                listener_metadata: @listener_metadata,
                encoding: @listener.encoding
              ).execute
            end

            metadata.merge!(time_elapsed: time_elapsed)
          end
        end
      end
    end
  end
end
