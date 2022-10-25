# frozen_string_literal: true

module Phobos
  module Producer
    # @!visibility private
    def self.included(base)
      base.extend(Phobos::Producer::ClassMethods)
      base.class_variable_set(:@@producer_config, :producer)
    end

    # @return [Phobos::Producer::PublicAPI]
    def producer
      Phobos::Producer::PublicAPI.new(self)
    end

    class PublicAPI
      def initialize(host_obj)
        @host_obj = host_obj
      end

      # @param topic [String]
      # @param payload [String]
      # @param key [String]
      # @param partition_key [Integer]
      # @param headers [Hash]
      # @return [void]
      def publish(topic:, payload:, key: nil, partition_key: nil, headers: nil)
        class_producer.publish(topic: topic,
                               payload: payload,
                               key: key,
                               partition_key: partition_key,
                               headers: headers)
      end

      # @param topic [String]
      # @param payload [String]
      # @param key [String]
      # @param partition_key [Integer]
      # @param headers [Hash]
      # @return [void]
      def async_publish(topic:, payload:, key: nil, partition_key: nil, headers: nil)
        class_producer.async_publish(topic: topic,
                                     payload: payload,
                                     key: key,
                                     partition_key: partition_key,
                                     headers: headers)
      end

      # @param messages [Array<Hash>]
      #        e.g.: [
      #          { topic: 'A', payload: 'message-1', key: '1', headers: { foo: 'bar' } },
      #          { topic: 'B', payload: 'message-2', key: '2', headers: { foo: 'bar' } }
      #        ]
      #
      def publish_list(messages)
        class_producer.publish_list(messages)
      end

      # @param messages [Array<Hash>]
      def async_publish_list(messages)
        class_producer.async_publish_list(messages)
      end

      private

      def class_producer
        @host_obj.class.producer
      end
    end

    module ClassMethods
      # @return [Phobos::Producer::ClassMethods::PublicAPI]
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
        # @return [Symbol]
        NAMESPACE = :phobos_producer_store
        # @return [Array<Symbol>]
        ASYNC_PRODUCER_PARAMS = [:max_queue_size, :delivery_threshold, :delivery_interval].freeze
        # @return [Array<Symbol>]
        INTERNAL_PRODUCER_PARAMS = [:persistent_connections].freeze

        def initialize(host_class)
          @host_class = host_class
        end

        # This method configures the kafka client used with publish operations
        # performed by the host class
        #
        # @param kafka_client [Kafka::Client]
        # @return [void]
        def configure_kafka_client(kafka_client)
          async_producer_shutdown
          producer_store[:kafka_client] = kafka_client
        end

        # @return [Kafka::Client]
        def kafka_client
          producer_store[:kafka_client]
        end

        # @return [Kafka::Producer]
        def create_sync_producer
          client = kafka_client || configure_kafka_client(create_kafka_client)
          sync_producer = client.producer(**regular_configs)
          if Phobos.config.producer_hash[:persistent_connections]
            producer_store[:sync_producer] = sync_producer
          end
          sync_producer
        end

        # @return [Kafka::Producer]
        def sync_producer
          producer_store[:sync_producer]
        end

        # @return [void]
        def sync_producer_shutdown
          sync_producer&.shutdown
          producer_store[:sync_producer] = nil
        end

        # @param topic [String]
        # @param payload [String]
        # @param partition_key [Integer]
        # @param headers [Hash]
        # @return [void]
        def publish(topic:, payload:, key: nil, partition_key: nil, headers: nil)
          publish_list([{ topic: topic, payload: payload, key: key,
                          partition_key: partition_key, headers: headers }])
        end

        # @param messages [Array<Hash>]
        # @return [void]
        def publish_list(messages)
          producer = sync_producer || create_sync_producer
          produce_messages(producer, messages)
          producer.deliver_messages
        ensure
          producer&.shutdown unless Phobos.config.producer_hash[:persistent_connections]
        end

        # @return [Kafka::AsyncProducer]
        def create_async_producer
          client = kafka_client || configure_kafka_client(create_kafka_client)
          async_producer = client.async_producer(**async_configs)
          producer_store[:async_producer] = async_producer
        end

        # @return [Kafka::AsyncProducer]
        def async_producer
          producer_store[:async_producer]
        end

        # @param topic [String]
        # @param payload [String]
        # @param partition_key [Integer]
        # @param headers [Hash]
        # @return [void]
        def async_publish(topic:, payload:, key: nil, partition_key: nil, headers: nil)
          async_publish_list([{ topic: topic, payload: payload, key: key,
                                partition_key: partition_key, headers: headers }])
        end

        # @param messages [Array<Hash>]
        # @return [void]
        def async_publish_list(messages)
          producer = async_producer || create_async_producer
          produce_messages(producer, messages)
          producer.deliver_messages unless async_automatic_delivery?
        end

        # @return [void]
        def async_producer_shutdown
          async_producer&.deliver_messages
          async_producer&.shutdown
          producer_store[:async_producer] = nil
        end

        # @return [Hash]
        def regular_configs
          Phobos.config.producer_hash
                .reject { |k, _| ASYNC_PRODUCER_PARAMS.include?(k) }
                .reject { |k, _| INTERNAL_PRODUCER_PARAMS.include?(k) }
        end

        # @return [Hash]
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
