module Phobos
  class Listener
    include Phobos::Instrumentation

    KAFKA_CONSUMER_OPTS = %i(session_timeout offset_commit_interval offset_commit_threshold heartbeat_interval).freeze
    DEFAULT_MAX_BYTES_PER_PARTITION = 524288 # 512 KB

    attr_reader :group_id, :topic, :id
    attr_reader :handler_class, :encoding

    def initialize(handler:, group_id:, topic:, min_bytes: nil,
                   max_wait_time: nil, force_encoding: nil,
                   start_from_beginning: true, backoff: nil,
                   max_bytes_per_partition: DEFAULT_MAX_BYTES_PER_PARTITION)
      @id = SecureRandom.hex[0...6]
      @handler_class = handler
      @group_id = group_id
      @topic = topic
      @backoff = backoff
      @subscribe_opts = {
        start_from_beginning: start_from_beginning,
        max_bytes_per_partition: max_bytes_per_partition
      }
      @encoding = Encoding.const_get(force_encoding.to_sym) if force_encoding
      @consumer_opts = compact(min_bytes: min_bytes, max_wait_time: max_wait_time)
      @kafka_client = Phobos.create_kafka_client
      @producer_enabled = @handler_class.ancestors.include?(Phobos::Producer)
    end

    def start
      @signal_to_stop = false
      instrument('listener.start', listener_metadata) do
        @consumer = create_kafka_consumer
        @consumer.subscribe(topic, @subscribe_opts)

        # This is done here because the producer client is bound to the current thread and
        # since "start" blocks a thread might be used to call it
        @handler_class.producer.configure_kafka_client(@kafka_client) if @producer_enabled

        instrument('listener.start_handler', listener_metadata) { @handler_class.start(@kafka_client) }
        Phobos.logger.info { Hash(message: 'Listener started').merge(listener_metadata) }
      end

      begin
        @consumer.each_batch(@consumer_opts) do |batch|
          batch_metadata = {
            batch_size: batch.messages.count,
            partition: batch.partition,
            offset_lag: batch.offset_lag,
            # the offset of the most recent message in the partition
            highwater_mark_offset: batch.highwater_mark_offset
          }.merge(listener_metadata)

          instrument('listener.process_batch', batch_metadata) do |batch_metadata|
            time_elapsed = measure do
              Phobos::Actions::ProcessBatch.new(
                listener: self,
                batch: batch,
                listener_metadata: listener_metadata
              ).execute
            end
            batch_metadata.merge!(time_elapsed: time_elapsed)
            Phobos.logger.info { Hash(message: 'Committed offset').merge(batch_metadata) }
          end

          return if should_stop?
        end

      # Abort is an exception to prevent the consumer from committing the offset.
      # Since "listener" had a message being retried while "stop" was called
      # it's wise to not commit the batch offset to avoid data loss. This will
      # cause some messages to be reprocessed
      #
      rescue Kafka::ProcessingError, Phobos::AbortError
        instrument('listener.retry_aborted', listener_metadata) do
          Phobos.logger.info do
            { message: 'Retry loop aborted, listener is shutting down' }.merge(listener_metadata)
          end
        end
      end

    ensure
      instrument('listener.stop', listener_metadata) do
        instrument('listener.stop_handler', listener_metadata) { @handler_class.stop }

        @consumer&.stop

        if @producer_enabled
          @handler_class.producer.async_producer_shutdown
          @handler_class.producer.configure_kafka_client(nil)
        end

        @kafka_client.close
        if should_stop?
          Phobos.logger.info { Hash(message: 'Listener stopped').merge(listener_metadata) }
        end
      end
    end

    def stop
      return if should_stop?
      instrument('listener.stopping', listener_metadata) do
        Phobos.logger.info { Hash(message: 'Listener stopping').merge(listener_metadata) }
        @consumer&.stop
        @signal_to_stop = true
      end
    end

    def create_exponential_backoff
      Phobos.create_exponential_backoff(@backoff)
    end

    def should_stop?
      @signal_to_stop == true
    end

    private

    def listener_metadata
      { listener_id: id, group_id: group_id, topic: topic }
    end

    def create_kafka_consumer
      configs = Phobos.config.consumer_hash.select { |k| KAFKA_CONSUMER_OPTS.include?(k) }
      @kafka_client.consumer({ group_id: group_id }.merge(configs))
    end

    def compact(hash)
      hash.delete_if { |_, v| v.nil? }
    end
  end
end
