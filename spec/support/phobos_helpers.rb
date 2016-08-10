module PhobosHelpers

  LISTENER_EVENTS = %w(
    listener.retry_aborted
    listener.retry_handler_error
    listener.process_message
    listener.process_batch
    listener.stop
    listener.start
  )

  EXECUTOR_EVENTS = %w(
    executor.retry_listener_error
    executor.stop
  )

  def phobos_config_path
    File.expand_path(File.join(File.dirname(__FILE__), '../../config/phobos.yml.example'))
  end

end
