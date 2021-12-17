# frozen_string_literal: true

module Phobos
  module Constants
    LOG_DATE_PATTERN = '%Y-%m-%dT%H:%M:%S:%L%zZ'

    KAFKA_CONSUMER_OPTS = [
      :session_timeout,
      :offset_commit_interval,
      :offset_commit_threshold,
      :heartbeat_interval,
      :offset_retention_time
    ].freeze

    LISTENER_OPTS = [
      :handler,
      :group_id,
      :topic,
      :min_bytes,
      :max_wait_time,
      :max_retries,
      :force_encoding,
      :start_from_beginning,
      :max_bytes_per_partition,
      :backoff,
      :delivery,
      :session_timeout,
      :offset_commit_interval,
      :offset_commit_threshold,
      :heartbeat_interval,
      :offset_retention_time
    ].freeze
  end
end
