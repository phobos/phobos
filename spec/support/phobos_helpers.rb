# frozen_string_literal: true

module PhobosHelpers
  LISTENER_EVENTS = %w[
    listener.retry_aborted
    listener.retry_handler_error
    listener.process_message
    listener.process_batch
    listener.stopping
    listener.stop
    listener.stop_handler
    listener.start
    listener.start_handler
  ].freeze

  EXECUTOR_EVENTS = %w[
    executor.retry_listener_error
    executor.stop
  ].freeze

  def phobos_config_path
    File.expand_path(File.join(File.dirname(__FILE__), '../../config/phobos.yml.example'))
  end
end
