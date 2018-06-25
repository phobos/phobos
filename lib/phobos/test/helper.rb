# frozen_string_literal: true

module Phobos
  module Test
    module Helper
      TOPIC = 'test-topic'
      GROUP = 'test-group'

      def process_message(handler:, payload:, metadata: {}, force_encoding: nil)
        listener = Phobos::Listener.new(
          handler: handler,
          group_id: GROUP,
          topic: TOPIC,
          force_encoding: force_encoding
        )

        message = Kafka::FetchedMessage.new(
          message: Kafka::Protocol::Message.new(value: payload, key: nil, offset: 13),
          topic: TOPIC,
          partition: 0
        )

        Phobos::Actions::ProcessMessage.new(
          listener: listener,
          message: message,
          listener_metadata: metadata
        ).execute
      end
    end
  end
end
