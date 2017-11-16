module Phobos
  module Test
    module Helper
      Topic = 'test-topic'
      Group = 'test-group'

      def process_message(handler:, payload:, metadata: {}, force_encoding: nil)
        listener = Phobos::Listener.new(
          handler: handler,
          group_id: Group,
          topic: Topic,
          force_encoding: force_encoding
        )

        message = Kafka::FetchedMessage.new(
          value: payload,
          key: nil,
          topic: Topic,
          partition: 0,
          offset: 13,
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
