require "bundler/setup"
require "phobos"

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
    loop do
      begin
        break if @stop
        key = SecureRandom.uuid

        #
        # Producer will use phobos configuration to create a kafka client and
        # a producer and it will bind both to the current thread, so it's safe
        # to call class methods here
        #
        MyProducer
          .producer
          .async_publish(TOPIC, Time.now.utc.to_json, key)

        puts "produced #{key}"

      #
      # Since this is a simplistic code we are going to generate more messages than
      # the producer can write to Kafka, so eventually we'll get some buffer overflows
      #
      rescue Kafka::BufferOverflow => e
        puts "| waiting"
        sleep(1)
      end
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
