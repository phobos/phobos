# frozen_string_literal: true

module Phobos
  class Executor
    include Phobos::Instrumentation
    LISTENER_OPTS = [:handler, :group_id, :topic, :min_bytes, :max_wait_time, :force_encoding, :start_from_beginning, :max_bytes_per_partition, :backoff, :delivery, :session_timeout, :offset_commit_interval, :offset_commit_threshold, :heartbeat_interval, :offset_retention_time].freeze

    def initialize
      @threads = Concurrent::Array.new
      @listeners = Phobos.config.listeners.flat_map do |config|
        handler_class = config.handler.constantize
        listener_configs = config.to_hash.deep_symbolize_keys
        max_concurrency = listener_configs[:max_concurrency] || 1
        Array.new(max_concurrency).map do
          configs = listener_configs.select { |k| LISTENER_OPTS.include?(k) }
          Phobos::Listener.new(configs.merge(handler: handler_class))
        end
      end
    end

    def start
      @signal_to_stop = false
      @threads.clear
      @thread_pool = Concurrent::FixedThreadPool.new(@listeners.size)

      @listeners.each do |listener|
        @thread_pool.post do
          thread = Thread.current
          thread.abort_on_exception = true
          @threads << thread
          run_listener(listener)
        end
      end

      true
    end

    def stop
      return if @signal_to_stop
      instrument('executor.stop') do
        @signal_to_stop = true
        @listeners.each(&:stop)
        @threads.select(&:alive?).each do |thread|
          thread.wakeup
        rescue StandardError
          nil
        end
        @thread_pool&.shutdown
        @thread_pool&.wait_for_termination
        Phobos.logger.info { Hash(message: 'Executor stopped') }
      end
    end

    private

    def error_metadata(e)
      {
        exception_class: e.class.name,
        exception_message: e.message,
        backtrace: e.backtrace
      }
    end

    def run_listener(listener)
      retry_count = 0
      backoff = listener.create_exponential_backoff

      begin
        listener.start
      rescue Exception => e
        #
        # When "listener#start" is interrupted it's safe to assume that the consumer
        # and the kafka client were properly stopped, it's safe to call start
        # again
        #
        interval = backoff.interval_at(retry_count).round(2)
        metadata = {
          listener_id: listener.id,
          retry_count: retry_count,
          waiting_time: interval
        }.merge(error_metadata(e))

        instrument('executor.retry_listener_error', metadata) do
          Phobos.logger.error { Hash(message: "Listener crashed, waiting #{interval}s (#{e.message})").merge(metadata) }
          sleep interval
        end

        retry_count += 1
        retry unless @signal_to_stop
      end
    rescue Exception => e
      Phobos.logger.error { Hash(message: "Failed to run listener (#{e.message})").merge(error_metadata(e)) }
      raise e
    end
  end
end
