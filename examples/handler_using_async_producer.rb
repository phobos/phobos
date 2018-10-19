# frozen_string_literal: true

#
# This example assumes you want to process the event and publish another
# one to kafka. A new event is always published thus we want to use the async producer
# to better use our resources and to speed up the process
#
class HandlerUsingAsyncProducer
  include Phobos::Handler
  include Phobos::Producer

  PUBLISH_TO 'another-topic'

  def consume(payload, _metadata)
    producer.async_publish(PUBLISH_TO, "#{payload}-#{rand}")
  end
end
