module Phobos
  class Listener
    include Phobos::Instrumentation

    KAFKA_CONSUMER_OPTS = %i(session_timeout offset_commit_interval offset_commit_threshold heartbeat_interval).freeze
    DEFAULT_MAX_BYTES_PER_PARTITION = 524288 # 512 KB

    attr_reader :group_id, :topic, :id

    def initialize(handler:, group_id:, topic:, start_from_beginning: true, max_bytes_per_partition: DEFAULT_MAX_BYTES_PER_PARTITION)
      @id = SecureRandom.hex[0...6]
      @handler_class = handler
      @group_id = group_id
      @topic = topic
      @subscribe_opts = {
        start_from_beginning: start_from_beginning,
        max_bytes_per_partition: max_bytes_per_partition
      }
      @kafka_client = Phobos.create_kafka_client
    end

    def start
      @signal_to_stop = false
      instrument('listener.start', listener_metadata) do
        @consumer = create_kafka_consumer
        @consumer.subscribe(topic, @subscribe_opts)
        instrument('listener.start_handler', listener_metadata) { @handler_class.start(@kafka_client) }
        Phobos.logger.info { Hash(message: 'Listener started').merge(listener_metadata) }
      end

      begin
        @consumer.each_batch do |batch|
          batch_metadata = {
            batch_size: batch.messages.count,
            partition: batch.partition,
            offset_lag: batch.offset_lag,
            # the offset of the most recent message in the partition
            highwater_mark_offset: batch.highwater_mark_offset
          }.merge(listener_metadata)

          instrument('listener.process_batch', batch_metadata) do
            process_batch(batch)
            Phobos.logger.info { Hash(message: 'Committed offset').merge(batch_metadata) }
          end

          return if @signal_to_stop
        end

      # Abort is an exception to prevent the consumer to commit the offset.
      # Since "listener" had a message being retried while "stop" was called
      # it's wise to not commit the batch offset to avoid data loss. This will
      # cause some messages to be reprocessed
      #
      rescue Phobos::AbortError
        instrument('listener.retry_aborted', listener_metadata) do
          Phobos.logger.info do
            {message: 'Retry loop aborted, listener is shutting down'}.merge(listener_metadata)
          end
        end
      end

    ensure
      instrument('listener.stop', listener_metadata) do
        instrument('listener.stop_handler', listener_metadata) { @handler_class.stop }

        @consumer&.stop
        @kafka_client.close

        if @signal_to_stop
          Phobos.logger.info { Hash(message: 'Listener stopped').merge(listener_metadata) }
        end
      end
    end

    def stop
      return if @signal_to_stop
      instrument('listener.stopping', listener_metadata) do
        Phobos.logger.info { Hash(message: 'Listener stopping').merge(listener_metadata) }
        @consumer&.stop
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
        metadata = listener_metadata.merge(
          key: message.key,
          partition: message.partition,
          offset: message.offset,
          retry_count: 0
        )

        begin
          instrument('listener.process_message', metadata) do
            process_message(message, metadata)
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
      payload = message.value
      @handler_class.around_consume(payload, metadata) do
        @handler_class.new.consume(payload, metadata)
      end
    end

    def create_kafka_consumer
      configs = Phobos.config.consumer_hash.select { |k| KAFKA_CONSUMER_OPTS.include?(k) }
      @kafka_client.consumer({group_id: group_id}.merge(configs))
    end
  end
end
