# frozen_string_literal: true

module Phobos
  # rubocop:disable Metrics/ParameterLists, Metrics/ClassLength
  class Listener
    include Phobos::Instrumentation
    include Phobos::Log

    DEFAULT_MAX_BYTES_PER_PARTITION = 1_048_576 # 1 MB
    DELIVERY_OPTS = %w[batch message inline_batch].freeze

    attr_reader :group_id, :topic, :id
    attr_reader :handler_class, :encoding, :consumer

    # rubocop:disable Metrics/MethodLength
    def initialize(handler:, group_id:, topic:, min_bytes: nil, max_wait_time: nil,
                   force_encoding: nil, start_from_beginning: true, backoff: nil,
                   delivery: 'batch', max_bytes_per_partition: DEFAULT_MAX_BYTES_PER_PARTITION,
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
        start_from_beginning: start_from_beginning, max_bytes_per_partition: max_bytes_per_partition
      }
      @kafka_consumer_opts = compact(
        session_timeout: session_timeout, offset_retention_time: offset_retention_time,
        offset_commit_interval: offset_commit_interval, heartbeat_interval: heartbeat_interval,
        offset_commit_threshold: offset_commit_threshold
      )
      @encoding = Encoding.const_get(force_encoding.to_sym) if force_encoding
      @message_processing_opts = compact(min_bytes: min_bytes, max_wait_time: max_wait_time)
      @kafka_client = Phobos.create_kafka_client(:consumer)
      @producer_enabled = @handler_class.ancestors.include?(Phobos::Producer)
    end
    # rubocop:enable Metrics/MethodLength

    def start
      @signal_to_stop = false

      start_listener

      begin
        start_consumer_loop
      rescue Kafka::ProcessingError, Phobos::AbortError
        # Abort is an exception to prevent the consumer from committing the offset.
        # Since "listener" had a message being retried while "stop" was called
        # it's wise to not commit the batch offset to avoid data loss. This will
        # cause some messages to be reprocessed
        instrument('listener.retry_aborted', listener_metadata) do
          log_info('Retry loop aborted, listener is shutting down', listener_metadata)
        end
      end
    ensure
      stop_listener
    end

    def stop
      return if should_stop?

      instrument('listener.stopping', listener_metadata) do
        log_info('Listener stopping', listener_metadata)
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

    def recreate_listener
      instrument('listener.recreate', listener_metadata) do
        @kafka_client.close
        @kafka_client = Phobos.create_kafka_client(:consumer)
      end
    end

    private

    def listener_metadata
      { listener_id: id, group_id: group_id, topic: topic, handler: handler_class.to_s }
    end

    def start_listener
      instrument('listener.start', listener_metadata) do
        @consumer = create_kafka_consumer
        @consumer.subscribe(topic, **@subscribe_opts)

        # This is done here because the producer client is bound to the current thread and
        # since "start" blocks a thread might be used to call it
        @handler_class.producer.configure_kafka_client(@kafka_client) if @producer_enabled

        instrument('listener.start_handler', listener_metadata) do
          @handler_class.start(@kafka_client)
        end
        log_info('Listener started', listener_metadata)
      end
    end

    def stop_listener
      instrument('listener.stop', listener_metadata) do
        instrument('listener.stop_handler', listener_metadata) { @handler_class.stop }

        @consumer&.stop

        if @producer_enabled
          @handler_class.producer.async_producer_shutdown
          @handler_class.producer.configure_kafka_client(nil)
        end

        @kafka_client.close
        log_info('Listener stopped', listener_metadata) if should_stop?
      end
    rescue NoMethodError => e
      log_error('Listener stop failed', { error: e.to_s })
    end

    def start_consumer_loop
      # validate batch handling
      case @delivery
      when 'batch'
        consume_each_batch
      when 'inline_batch'
        consume_each_batch_inline
      else
        consume_each_message
      end
    end

    def consume_each_batch
      @consumer.each_batch(**@message_processing_opts) do |batch|
        batch_processor = Phobos::Actions::ProcessBatch.new(
          listener: self,
          batch: batch,
          listener_metadata: listener_metadata
        )

        batch_processor.execute
        log_debug('Committed offset', batch_processor.metadata)
        return nil if should_stop?
      end
    end

    def consume_each_batch_inline
      @consumer.each_batch(**@message_processing_opts) do |batch|
        batch_processor = Phobos::Actions::ProcessBatchInline.new(
          listener: self,
          batch: batch,
          metadata: listener_metadata
        )

        batch_processor.execute
        log_debug('Committed offset', batch_processor.metadata)
        return nil if should_stop?
      end
    end

    def consume_each_message
      @consumer.each_message(**@message_processing_opts) do |message|
        message_processor = Phobos::Actions::ProcessMessage.new(
          listener: self,
          message: message,
          listener_metadata: listener_metadata
        )

        message_processor.execute
        log_debug('Committed offset', message_processor.metadata)
        return nil if should_stop?
      end
    end

    def create_kafka_consumer
      configs = Phobos.config.consumer_hash.select do |k|
        Constants::KAFKA_CONSUMER_OPTS.include?(k)
      end
      configs.merge!(@kafka_consumer_opts)
      @kafka_client.consumer(**{ group_id: group_id }.merge(configs))
    end

    def compact(hash)
      hash.delete_if { |_, v| v.nil? }
    end
  end
  # rubocop:enable Metrics/ParameterLists, Metrics/ClassLength
end
