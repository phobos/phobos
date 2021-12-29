# frozen_string_literal: true

module Phobos
  module Producer
    def self.included(base)
      base.extend(Phobos::Producer::ClassMethods)
      base.class_variable_set(:@@producer_config, :producer)
    end

    def producer
      Phobos::Producer::PublicAPI.new(self)
    end

    class PublicAPI
      def initialize(host_obj)
        @host_obj = host_obj
      end

      def publish(topic:, payload:, key: nil, partition_key: nil, headers: nil)
        class_producer.publish(topic: topic,
                               payload: payload,
                               key: key,
                               partition_key: partition_key,
                               headers: headers)
      end

      def async_publish(topic:, payload:, key: nil, partition_key: nil, headers: nil)
        class_producer.async_publish(topic: topic,
                                     payload: payload,
                                     key: key,
                                     partition_key: partition_key,
                                     headers: headers)
      end

      # @param messages [Array(Hash(:topic, :payload, :key, :headers))]
      #        e.g.: [
      #          { topic: 'A', payload: 'message-1', key: '1', headers: { foo: 'bar' } },
      #          { topic: 'B', payload: 'message-2', key: '2', headers: { foo: 'bar' } }
      #        ]
      #
      def publish_list(messages)
        class_producer.publish_list(messages)
      end

      def async_publish_list(messages)
        class_producer.async_publish_list(messages)
      end

      private

      def class_producer
        @host_obj.class.producer
      end
    end

    module ClassMethods
      def producer
        Phobos::Producer::ClassMethods::PublicAPI.new(self)
      end

      def producer_config
        class_variable_get :@@producer_config
      end

      def configure_producer(producer)
        class_variable_set :@@producer_config, producer
      end

      class PublicAPI
        NAMESPACE = :phobos_producer_store
        ASYNC_PRODUCER_PARAMS = [:max_queue_size, :delivery_threshold, :delivery_interval].freeze
        INTERNAL_PRODUCER_PARAMS = [:persistent_connections].freeze

        def initialize(host_class)
          @host_class = host_class
        end

        # This method configures the kafka client used with publish operations
        # performed by the host class
        #
        # @param kafka_client [Kafka::Client]
        #
        def configure_kafka_client(kafka_client)
          async_producer_shutdown
          producer_store[:kafka_client] = kafka_client
        end

        def kafka_client
          producer_store[:kafka_client]
        end

        def create_sync_producer
          client = kafka_client || configure_kafka_client(create_kafka_client)
          sync_producer = client.producer(**regular_configs)
          if Phobos.config.producer_hash[:persistent_connections]
            producer_store[:sync_producer] = sync_producer
          end
          sync_producer
        end

        def sync_producer
          producer_store[:sync_producer]
        end

        def sync_producer_shutdown
          sync_producer&.shutdown
          producer_store[:sync_producer] = nil
        end

        def publish(topic:, payload:, key: nil, partition_key: nil, headers: nil)
          publish_list([{ topic: topic, payload: payload, key: key,
                          partition_key: partition_key, headers: headers }])
        end

        def publish_list(messages)
          producer = sync_producer || create_sync_producer
          produce_messages(producer, messages)
          producer.deliver_messages
        ensure
          producer&.shutdown unless Phobos.config.producer_hash[:persistent_connections]
        end

        def create_async_producer
          client = kafka_client || configure_kafka_client(create_kafka_client)
          async_producer = client.async_producer(**async_configs)
          producer_store[:async_producer] = async_producer
        end

        def async_producer
          producer_store[:async_producer]
        end

        def async_publish(topic:, payload:, key: nil, partition_key: nil, headers: nil)
          async_publish_list([{ topic: topic, payload: payload, key: key,
                                partition_key: partition_key, headers: headers }])
        end

        def async_publish_list(messages)
          producer = async_producer || create_async_producer
          produce_messages(producer, messages)
          producer.deliver_messages unless async_automatic_delivery?
        end

        def async_producer_shutdown
          async_producer&.deliver_messages
          async_producer&.shutdown
          producer_store[:async_producer] = nil
        end

        def regular_configs
          Phobos.config.producer_hash
                .reject { |k, _| ASYNC_PRODUCER_PARAMS.include?(k) }
                .reject { |k, _| INTERNAL_PRODUCER_PARAMS.include?(k) }
        end

        def async_configs
          Phobos.config.producer_hash
                .reject { |k, _| INTERNAL_PRODUCER_PARAMS.include?(k) }
        end

        private

        def create_kafka_client
          Phobos.create_kafka_client(@host_class.producer_config)
        end

        def produce_messages(producer, messages)
          messages.each do |message|
            partition_key = message[:partition_key] || message[:key]
            producer.produce(message[:payload], topic: message[:topic],
                                                key: message[:key],
                                                headers: message[:headers],
                                                partition_key: partition_key)
          end
        end

        def async_automatic_delivery?
          async_configs.fetch(:delivery_threshold, 0).positive? ||
            async_configs.fetch(:delivery_interval, 0).positive?
        end

        def producer_store
          Thread.current[NAMESPACE] ||= {}
          if @host_class.producer_config
            Thread.current[NAMESPACE][@host_class.producer_config] ||= {}
          else
            Thread.current[NAMESPACE]
          end
        end
      end
    end
  end
end
