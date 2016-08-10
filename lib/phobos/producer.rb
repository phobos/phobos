module Phobos
  module Producer

    def publish(topic, payload, key = nil)
      klafka_client = Phobos.create_kafka_client
      klafka_client.deliver_message(payload, topic: topic, partition_key: key)
    ensure
      klafka_client&.close
    end

  end
end
