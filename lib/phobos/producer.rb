module Phobos
  module Producer
    def publish(topic, payload, key = nil)
      Phobos
        .create_kafka_client
        .deliver_message(payload, topic: topic, partition_key: key)
    end
  end
end
