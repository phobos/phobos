module Phobos
  module Test
    module Helper
      Topic = 'test-topic'
      Group = 'test-group'
      KafkaMessage = Struct.new(:value)

      def process_message(handler:, payload:, metadata:, force_encoding: nil)
        listener = Phobos::Listener.new(
          handler: handler,
          group_id: Group,
          topic: Topic,
          force_encoding: force_encoding
        )

        Phobos::Actions::ProcessMessage.new(
          listener: listener,
          message: KafkaMessage.new(payload),
          metadata: metadata,
          encoding: listener.encoding
        ).execute
      end
    end
  end
end
