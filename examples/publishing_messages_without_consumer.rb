#
# This example assumes you want to create a threaded kafka generator which
# publish a stream of kafka messages without consuming them. It also shows
# what happens when you produce more messages than the producer can handle.
#
require 'bundler/setup'
require 'json'
require 'phobos'

TOPIC = 'test-partitions'

Phobos.configure('config/phobos.yml')

class MyProducer
  include Phobos::Producer
end

#
# Trapping signals to properly stop this generator
#
@stop = false
%i( INT TERM QUIT ).each do |signal|
  Signal.trap(signal) do
    puts "Stopping"
    @stop = true
  end
end

Thread.new do
  begin
    total = 1

    loop do
      break if @stop
      key = SecureRandom.uuid
      payload = Time.now.utc.to_json

      begin
        # Producer will use phobos configuration to create a kafka client and
        # a producer and it will bind both to the current thread, so it's safe
        # to call class methods here
        #
        MyProducer
          .producer
          .async_publish(TOPIC, payload, key)

        puts "produced #{key}, total: #{total}"

      # Since this is very simplistic code, we are going to generate more messages than
      # the producer can write to Kafka. Eventually we'll get some buffer overflows
      #
      rescue Kafka::BufferOverflow => e
        puts "| waiting"
        sleep(1)
        retry
      end

      total += 1
    end
  ensure
    #
    # Before we stop we must shutdown the async producer to ensure that all messages
    # are delivered
    #
    MyProducer
      .producer
      .async_producer_shutdown

    #
    # Since no client was configured (we can do this with `MyProducer.producer.configure_kafka_client`)
    # we must get the auto generated one and close it properly
    #
    MyProducer
      .producer
      .kafka_client
      .close
  end
end.join
