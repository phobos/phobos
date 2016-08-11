module Phobos
  class Listener
    include Phobos::Instrumentation

    attr_reader :group_id, :topic, :id

    def initialize(handler:, group_id:, topic:, start_from_beginning:)
      @id = SecureRandom.hex[0...6]
      @handler_class = handler
      @group_id = group_id
      @topic = topic
      @start_from_beginning = start_from_beginning
      @kafka_client = Phobos.create_kafka_client
    end

    def start
      @signal_to_stop = false
      instrument('listener.start', listener_metadata) do
        @consumer = create_kafka_consumer
        @consumer.subscribe(topic, start_from_beginning: @start_from_beginning)
        Phobos.logger.info { Hash(message: 'Listener started').merge(listener_metadata) }
      end

      @consumer.each_batch do |batch|
        batch_metadata = {
          batch_size: batch.messages.count,
          partition: batch.partition,
          offset_lag: batch.offset_lag,
          highwater_mark_offset: batch.highwater_mark_offset
        }.merge(listener_metadata)

        instrument('listener.process_batch', batch_metadata) { process_batch(batch) }
      end

      if @signal_to_stop
        Phobos.logger.info { Hash(message: 'Listener stopped').merge(listener_metadata) }
      end
    rescue Phobos::AbortError
      instrument('listener.retry_aborted', listener_metadata) do
        Phobos.logger.info do
          {message: 'Retry loop aborted, listener is shutting down'}.merge(listener_metadata)
        end
      end
    end

    def stop
      instrument('listener.stop') do
        Phobos.logger.info { Hash(message: 'Listener stopping').merge(listener_metadata) }
        @consumer&.stop
        @kafka_client.close
        @signal_to_stop = true
      end
    end

    private

    def listener_metadata
      { listener_id: id, group_id: group_id, topic: topic }
    end

    def process_batch(batch)
      batch.messages.each do |message|
        backoff = Phobos.create_exponential_backoff
        partition = batch.partition
        metadata = listener_metadata.merge(
          key: message.key,
          partition: partition,
          offset: message.offset,
          retry_count: 0
        )

        begin
          instrument('listener.process_message', metadata) do
            process_message(message, metadata)
          end
          break
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
              {message: "error processing message, waiting #{interval}s"}.merge(error).merge(metadata)
            end

            sleep interval
            metadata.merge!(retry_count: retry_count + 1)
          end

          raise Phobos::AbortError if @signal_to_stop
          retry
        end
      end
    end

    def process_message(message, metadata)
      @handler_class.new.consume(message.value, metadata)
    end

    def create_kafka_consumer
      consumer_configs = Phobos.config.consumer.to_hash.symbolize_keys
      @kafka_client.consumer({group_id: group_id}.merge(consumer_configs))
    end

  end
end
