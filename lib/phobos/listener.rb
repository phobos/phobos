# frozen_string_literal: true

module Phobos
  class Listener
    include Phobos::Instrumentation

    KAFKA_CONSUMER_OPTS = [:session_timeout, :offset_commit_interval, :offset_commit_threshold, :heartbeat_interval, :offset_retention_time].freeze

    DEFAULT_MAX_BYTES_PER_PARTITION = 1_048_576 # 1 MB
    DELIVERY_OPTS = %w[batch message].freeze

    attr_reader :group_id, :topic, :id
    attr_reader :handler_class, :encoding

    def initialize(handler:, group_id:, topic:, min_bytes: nil,
                   max_wait_time: nil, force_encoding: nil,
                   start_from_beginning: true, backoff: nil,
                   delivery: 'batch',
                   max_bytes_per_partition: DEFAULT_MAX_BYTES_PER_PARTITION,
                   session_timeout: nil, offset_commit_interval: nil,
                   heartbeat_interval: nil, offset_commit_threshold: nil,
                   offset_retention_time: nil)
      @id = SecureRandom.hex[0...6]
      @handler_class = handler
      @group_id = group_id
      @topic = topic
      @backoff = backoff
      @delivery = delivery.to_s
      @subscribe_opts = {
        start_from_beginning: start_from_beginning,
        max_bytes_per_partition: max_bytes_per_partition
      }
      @kafka_consumer_opts = compact(
        session_timeout: session_timeout,
        offset_commit_interval: offset_commit_interval,
        heartbeat_interval: heartbeat_interval,
        offset_retention_time: offset_retention_time,
        offset_commit_threshold: offset_commit_threshold
      )
      @encoding = Encoding.const_get(force_encoding.to_sym) if force_encoding
      @message_processing_opts = compact(min_bytes: min_bytes, max_wait_time: max_wait_time)
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
        @delivery == 'batch' ? consume_each_batch : consume_each_message

      # Abort is an exception to prevent the consumer from committing the offset.
      # Since "listener" had a message being retried while "stop" was called
      # it's wise to not commit the batch offset to avoid data loss. This will
      # cause some messages to be reprocessed
      #
      rescue Kafka::ProcessingError, Phobos::AbortError
        instrument('listener.retry_aborted', listener_metadata) do
          Phobos.logger.info({ message: 'Retry loop aborted, listener is shutting down' }.merge(listener_metadata))
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

    def consume_each_batch
      @consumer.each_batch(@message_processing_opts) do |batch|
        batch_processor = Phobos::Actions::ProcessBatch.new(
          listener: self,
          batch: batch,
          listener_metadata: listener_metadata
        )

        batch_processor.execute
        Phobos.logger.debug { Hash(message: 'Committed offset').merge(batch_processor.metadata) }
        return if should_stop?
      end
    end

    def consume_each_message
      @consumer.each_message(@message_processing_opts) do |message|
        message_processor = Phobos::Actions::ProcessMessage.new(
          listener: self,
          message: message,
          listener_metadata: listener_metadata
        )

        message_processor.execute
        Phobos.logger.debug { Hash(message: 'Committed offset').merge(message_processor.metadata) }
        return if should_stop?
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

    def send_heartbeat_if_necessary
      raise Phobos::AbortError if should_stop?

      @consumer&.send_heartbeat_if_necessary
    end

    private

    def listener_metadata
      { listener_id: id, group_id: group_id, topic: topic, handler: handler_class.to_s }
    end

    def create_kafka_consumer
      configs = Phobos.config.consumer_hash.select { |k| KAFKA_CONSUMER_OPTS.include?(k) }
      configs.merge!(@kafka_consumer_opts)
      @kafka_client.consumer({ group_id: group_id }.merge(configs))
    end

    def compact(hash)
      hash.delete_if { |_, v| v.nil? }
    end
  end
end
