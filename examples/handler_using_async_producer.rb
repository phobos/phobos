class HandlerUsingAsyncProducer
  include Phobos::Handler
  include Phobos::Producer

  def self.start(kafka_client)
    # Configuring producer client with the same client of the consumer
    producer.configure_kafka_client(kafka_client)
    producer.create_async_producer
  end

  def self.stop
    # Make sure to call `async_producer_shutdown` in order to avoid leaking
    # resources. This method will wait for any pending messages to be delivered
    # before returning
    producer.async_producer_shutdown
  end

  def consume(payload, metadata)
    producer.async_publish(metadata[:topic], "#{payload}-#{rand}")
  end
end
