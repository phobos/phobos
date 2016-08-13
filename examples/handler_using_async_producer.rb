#
# This example assumes you want to process the event and publish another
# one to kafka. A new event is always published thus we want to use the async producer
# to better use our resources and to speed up the process
#
class HandlerUsingAsyncProducer
  include Phobos::Handler
  include Phobos::Producer

  def self.start(kafka_client)
    #
    # Configuring producer client with the same client of the consumer
    #
    producer.configure_kafka_client(kafka_client)
  end

  def consume(payload, metadata)
    producer.async_publish(metadata[:topic], "#{payload}-#{rand}")
  end

  def self.stop
    #
    # Make sure to call `async_producer_shutdown` in order to avoid leaking
    # resources. This method will wait for any pending messages to be delivered
    # before returning
    #
    producer.async_producer_shutdown
  end
end
