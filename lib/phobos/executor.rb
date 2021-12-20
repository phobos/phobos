# frozen_string_literal: true

module Phobos
  class Executor
    include Phobos::Instrumentation
    include Phobos::Log

    def initialize
      @threads = Concurrent::Array.new
      @listeners = Phobos.config.listeners.flat_map do |config|
        handler_class = config.handler.constantize
        listener_configs = config.to_hash.deep_symbolize_keys
        max_concurrency = listener_configs[:max_concurrency] || 1
        Array.new(max_concurrency).map do
          configs = listener_configs.select { |k| Constants::LISTENER_OPTS.include?(k) }
          Phobos::Listener.new(**configs.merge(handler: handler_class))
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
          begin
            thread.wakeup
          rescue StandardError
            nil
          end
        end
        @thread_pool&.shutdown
        @thread_pool&.wait_for_termination
        Phobos.logger.info { Hash(message: 'Executor stopped') }
      end
    end

    private

    def error_metadata(exception)
      {
        exception_class: exception.class.name,
        exception_message: exception.message,
        backtrace: exception.backtrace
      }
    end

    # rubocop:disable Lint/RescueException
    def run_listener(listener)
      retry_count = 0

      begin
        listener.start
      rescue Exception => e
        handle_crashed_listener(listener, e, retry_count)
        retry_count += 1
        # if failed too many times, try to recreate the listener
        listener.recreate_listener if retry_count > 42
        retry unless @signal_to_stop
      end
    rescue Exception => e
      log_error("Failed to run listener (#{e.message})", error_metadata(e))
      raise e
    end
    # rubocop:enable Lint/RescueException

    # When "listener#start" is interrupted it's safe to assume that the consumer
    # and the kafka client were properly stopped, it's safe to call start
    # again
    def handle_crashed_listener(listener, error, retry_count)
      backoff = listener.create_exponential_backoff
      interval = backoff.interval_at(retry_count).round(2)

      metadata = {
        listener_id: listener.id,
        retry_count: retry_count,
        waiting_time: interval
      }.merge(error_metadata(error))

      instrument('executor.retry_listener_error', metadata) do
        log_error("Listener crashed, waiting #{interval}s (#{error.message})", metadata)
        sleep interval
      end
    end
  end
end
