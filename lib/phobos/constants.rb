# frozen_string_literal: true

module Phobos
  module Constants
    KAFKA_CONSUMER_OPTS = [
      :session_timeout,
      :offset_commit_interval,
      :offset_commit_threshold,
      :heartbeat_interval,
      :offset_retention_time
    ].freeze
  end
end
