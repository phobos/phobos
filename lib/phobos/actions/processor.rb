# frozen_string_literal: true

require 'active_support/concern'

module Phobos
  module Actions
    module Processor
      extend ActiveSupport::Concern
      include Phobos::Instrumentation

      MAX_SLEEP_INTERVAL = 3

      def snooze(interval)
        remaining_interval = interval

        @listener.send_heartbeat_if_necessary

        while remaining_interval.positive?
          sleep [remaining_interval, MAX_SLEEP_INTERVAL].min
          remaining_interval -= MAX_SLEEP_INTERVAL
          @listener.send_heartbeat_if_necessary
        end
      end

      private

      def force_encoding(value)
        @listener.encoding ? value&.force_encoding(@listener.encoding) : value
      end

      def handle_error(error, instrumentation_key, error_message)
        error_hash = {
          waiting_time: backoff_interval,
          exception_class: error.class.name,
          exception_message: error.message,
          backtrace: error.backtrace
        }

        instrument(instrumentation_key, error_hash.merge(@metadata)) do
          Phobos.logger.error do
            { message: error_message }
              .merge(error_hash)
              .merge(@metadata)
          end

          snooze(backoff_interval)
        end

        increment_retry_count
      end

      def retry_count
        @metadata[:retry_count]
      end

      def increment_retry_count
        @metadata[:retry_count] = retry_count + 1
      end

      def backoff
        @backoff ||= @listener.create_exponential_backoff
      end

      def backoff_interval
        backoff.interval_at(retry_count).round(2)
      end
    end
  end
end
