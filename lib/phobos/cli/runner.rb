# frozen_string_literal: true

module Phobos
  module CLI
    class Runner
      SIGNALS = [:INT, :TERM, :QUIT].freeze

      def initialize
        @signal_queue = []
        @reader, @writer = IO.pipe
        @executor = Phobos::Executor.new
      end

      def run!
        setup_signals
        executor.start

        loop do
          case signal_queue.pop
          when *SIGNALS
            executor.stop
            break
          else
            ready = IO.select([reader, writer])

            # drain the self-pipe so it won't be returned again next time
            reader.read_nonblock(1) if ready[0].include?(reader)
          end
        end
      end

      private

      attr_reader :reader, :writer, :signal_queue, :executor

      def setup_signals
        SIGNALS.each do |signal|
          Signal.trap(signal) { unblock(signal) }
        end
      end

      def unblock(signal)
        writer.write_nonblock('.')
        signal_queue << signal
      end
    end
  end
end
