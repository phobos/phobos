module Phobos
  class Listener
    include Phobos::Instrumentation

    attr_reader :group_id, :topic

    def initialize(handler_class, group_id:, topic:)
      @handler_class = handler_class
      @group_id = group_id
      @topic = topic
      @kafka_client = Phobos.create_kafka_client
    end

    def start
      instrument('listener.start', listener_metadata) do
        @handler = @handler_class.new
        @consumer = @kafka_client.consumer(group_id: group_id)
        @consumer.subscribe(topic)
      end

      @consumer.each_batch do |batch|
        batch_metadata = {
          batch_size: batch.messages.count,
          partition: batch.partition,
          offset_lag: batch.offset_lag,
          highwater_mark_offset: batch.highwater_mark_offset
        }.merge(listener_metadata)

        begin
          instrument('listener.process_batch', batch_metadata) { process_batch(batch) }
        rescue => e
          Phobos.logger.error do
            {
              message: "Error processing batch: #{e.message}",
              backtrace: e.backtrace
            }.merge(batch_metadata)
          end
        end
      end
    end

    def stop
      Thread.current.wakeup
      instrument('listener.stop') do
        @consumer.stop
        @kafka_client.close
      end
    end

    private

    def listener_metadata
      { group_id: group_id, topic: topic }
    end

    def process_batch(batch)
      batch.messages.each do |message|
        backoff = create_exponential_backoff
        partition = batch.partition
        metadata = {
          key: message.key,
          partition: partition,
          offset: message.offset,
          retry_count: 0
        }.merge(listener_metadata)

        loop do
          begin
            instrument('listener.process_message', metadata) { process_message(message, metadata) }
            break
          rescue Exception => e
            retry_count = metadata[:retry_count]
            interval = backoff.interval_at(retry_count).round(2)

            error = {
              exception_class: e.class.name,
              exception_message: e.message,
              backtrace: e.backtrace,
              waiting_time: interval
            }

            instrument('listener.retry_handler_error', error.merge(metadata)) do
              Phobos.logger.error do
                {message: "error processing message, waiting #{interval}s"}.merge(error).merge(metadata)
              end

              sleep interval
              metadata.merge!(retry_count: retry_count + 1)
            end
          end
        end
      end
    end

    def process_message(message, metadata)
      @handler.consume(message.value, metadata)
    end

    def create_exponential_backoff
      min = Phobos.config.backoff.min_ms / 1000.0
      max = Phobos.config.backoff.max_ms / 1000.0
      ExponentialBackoff.new(min, max).tap { |backoff| backoff.randomize_factor = rand }
    end

  end
end
