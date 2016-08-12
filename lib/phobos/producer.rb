module Phobos
  module Producer
    def self.included(base)
      base.extend(Phobos::Producer::ClassMethods)
    end

    def producer
      Phobos::Producer::PublicAPI.new(self)
    end

    class PublicAPI
      def initialize(host_obj)
        @host_obj = host_obj
      end

      def publish(topic, payload, key = nil)
        publish_list([{ topic: topic, payload: payload, key: key }])
      end

      def async_publish(topic, payload, key = nil)
        async_publish_list([{ topic: topic, payload: payload, key: key }])
      end

      # @param messages [Array(Hash(:topic, :payload, :key))]
      #        e.g.: [
      #          { topic: 'A', payload: 'message-1', key: '1' },
      #          { topic: 'B', payload: 'message-2', key: '2' },
      #        ]
      #
      def publish_list(messages)
        client = kafka_client || Phobos.create_kafka_client
        producer = client.producer(Phobos.config.producer_hash)
        produce_messages(producer, messages)
      ensure
        client&.close unless kafka_client
      end

      def async_publish_list(messages)
        producer = async_producer
        unless producer
          raise(
            Phobos::AsyncProducerNotConfiguredError,
            <<-MESSAGE
              async_producer is not configured, you must call the class method `producer.create_async_producer`
              to create it first
            MESSAGE
            .gsub(/\s+/, ' ')
          )
        end
        produce_messages(producer, messages)
      end

      private

      def produce_messages(producer, messages)
        messages.each do |message|
          producer.produce(
            message[:payload],
            topic: message[:topic],
            key: message[:key],
            partition_key: message[:key]
          )
        end
        producer.deliver_messages
      end

      def kafka_client
        @host_obj.class.producer.kafka_client
      end

      def async_producer
        @host_obj.class.producer.async_producer
      end
    end

    module ClassMethods
      def producer
        Phobos::Producer::ClassMethods::PublicAPI.new
      end

      class PublicAPI
        NAMESPACE = :phobos_producer_store

        # This method configures the kafka client used with publish operations
        # performed by the host class. Configure a client to avoid opening/closing
        # connections for every sync messages
        # @param kafka_client [Kafka::Client]
        #
        def configure_kafka_client(kafka_client)
          async_producer_shutdown
          producer_store[:kafka_client] = kafka_client
        end

        def kafka_client
          producer_store[:kafka_client]
        end

        def create_async_producer
          client = kafka_client || configure_kafka_client(Phobos.create_kafka_client)
          async_producer = client.async_producer(Phobos.config.producer_hash)
          producer_store[:async_producer] = async_producer
        end

        def async_producer
          producer_store[:async_producer]
        end

        def async_producer_shutdown
          async_producer&.deliver_messages
          async_producer&.shutdown
          producer_store[:async_producer] = nil
        end

        private

        def producer_store
          Thread.current[NAMESPACE] ||= {}
        end
      end
    end
  end
end
