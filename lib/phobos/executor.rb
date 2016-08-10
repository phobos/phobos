module Phobos
  class Executor
    include Phobos::Instrumentation

    def initialize
      @threads = Concurrent::Array.new
      @listeners = Phobos.config.listeners.map do |config|
        handler_class = config.handler.constantize
        listener_configs= config.to_hash.symbolize_keys
        Phobos::Listener.new(listener_configs.merge(handler: handler_class))
      end

      trap('QUIT') { self.stop }
    end

    def start
      @signal_to_stop = false
      @threads.clear
      @thread_pool = Concurrent::FixedThreadPool.new(Phobos.config.listeners.size)

      @listeners.each do |listener|
        @thread_pool.post do
          @threads << Thread.current
          run_listener(listener)
        end
      end

      true
    end

    def stop
      instrument('executor.stop') do
        @signal_to_stop = true
        @listeners.map(&:stop)
        @threads.select(&:alive?).each { |thread| thread.wakeup rescue nil }
        @thread_pool&.shutdown
        @thread_pool&.wait_for_termination
        Phobos.logger.info { Hash(message: 'Executor stopped') }
      end
    end

    private

    def run_listener(listener)
      retry_count = 0
      backoff = Phobos.create_exponential_backoff

      begin
        listener.start
      rescue Exception => e
        interval = backoff.interval_at(retry_count).round(2)
        metadata = {
          listener_id: listener.id,
          retry_count: retry_count,
          waiting_time: interval,
          exception_class: e.class.name,
          exception_message: e.message,
          backtrace: e.backtrace
        }

        instrument('executor.retry_listener_error', metadata) do
          Phobos.logger.error { Hash(message: "Listener crashed, waiting #{interval}s (#{e.message})").merge(metadata)}
          listener.stop
          sleep interval
        end

        retry_count += 1
        retry unless @signal_to_stop
      end
    end

  end
end
