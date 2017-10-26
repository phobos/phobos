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
          backoff = @listener.create_exponential_backoff
          metadata = @listener_metadata.merge(
            key: message.key,
            partition: message.partition,
            offset: message.offset,
            retry_count: 0
          )

          begin
            instrument('listener.process_message', metadata) do |metadata|
              time_elapsed = measure do
                Phobos::Actions::ProcessMessage.new(
                  listener: @listener,
                  message: message,
                  metadata: metadata,
                  encoding: @listener.encoding
                ).execute
              end
              metadata.merge!(time_elapsed: time_elapsed)
            end
          rescue => e
            retry_count = metadata[:retry_count]
            interval = backoff.interval_at(retry_count).round(2)

            error = {
              waiting_time: interval,
              exception_class: e.class.name,
              exception_message: e.message,
              backtrace: e.backtrace
            }

            instrument('listener.retry_handler_error', error.merge(metadata)) do
              Phobos.logger.error do
                { message: "error processing message, waiting #{interval}s" }.merge(error).merge(metadata)
              end

              sleep interval
              metadata.merge!(retry_count: retry_count + 1)
            end

            raise Phobos::AbortError if @listener.should_stop?
            retry
          end
        end
      end
    end
  end
end
