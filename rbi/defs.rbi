# typed: strong
# Please use this with at least the same consideration as you would when using OpenStruct.
# Right now we only use this to parse our internal configuration files. It is not meant to
# be used on incoming data.
module Phobos
  extend Phobos::Configuration
  VERSION = T.let('2.1.4', T.untyped)

  class << self
    sig { returns(Phobos::DeepStruct) }
    attr_reader :config

    sig { returns(Logger) }
    attr_reader :logger

    sig { returns(T::Boolean) }
    attr_accessor :silence_log
  end

  # _@param_ `configuration`
  sig { params(configuration: T::Hash[String, Object]).void }
  def self.add_listeners(configuration); end

  # _@param_ `config_key`
  sig { params(config_key: T.nilable(String)).returns(T.untyped) }
  def self.create_kafka_client(config_key = nil); end

  # _@param_ `backoff_config`
  sig { params(backoff_config: T.nilable(T::Hash[Symbol, Integer])).returns(T.untyped) }
  def self.create_exponential_backoff(backoff_config = nil); end

  # _@param_ `message`
  sig { params(message: String).void }
  def self.deprecate(message); end

  # _@param_ `configuration`
  sig { params(configuration: T.untyped).void }
  def self.configure(configuration); end

  sig { void }
  def self.configure_logger; end

  module Log
    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_info(msg, metadata = {}); end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_debug(msg, metadata = {}); end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_error(msg, metadata); end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_warn(msg, metadata = {}); end
  end

  module LoggerHelper
    sig { params(method: T.untyped, msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def self.log(method, msg, metadata); end
  end

  class Error < StandardError
  end

  class AbortError < Phobos::Error
  end

  module Handler
    sig { params(_payload: T.untyped, _metadata: T.untyped).returns(T.untyped) }
    def consume(_payload, _metadata); end

    sig { params(payload: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def around_consume(payload, metadata); end

    module ClassMethods
      sig { params(kafka_client: T.untyped).returns(T.untyped) }
      def start(kafka_client); end

      sig { returns(T.untyped) }
      def stop; end
    end
  end

  class Executor
    include Phobos::Instrumentation
    include Phobos::Log

    sig { void }
    def initialize; end

    sig { returns(T.untyped) }
    def start; end

    sig { returns(T.untyped) }
    def stop; end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_info(msg, metadata = {}); end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_debug(msg, metadata = {}); end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_error(msg, metadata); end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_warn(msg, metadata = {}); end

    sig { params(event: T.untyped, extra: T.untyped).returns(T.untyped) }
    def instrument(event, extra = {}); end
  end

  # rubocop:disable Metrics/ParameterLists, Metrics/ClassLength
  class Listener
    include Phobos::Instrumentation
    include Phobos::Log
    DEFAULT_MAX_BYTES_PER_PARTITION = T.let(1_048_576, T.untyped)
    DELIVERY_OPTS = T.let(%w[batch message inline_batch].freeze, T.untyped)

    # rubocop:disable Metrics/MethodLength
    # 
    # _@param_ `handler`
    # 
    # _@param_ `group_id`
    # 
    # _@param_ `topic`
    # 
    # _@param_ `min_bytes`
    # 
    # _@param_ `max_wait_time`
    # 
    # _@param_ `start_from_beginning`
    # 
    # _@param_ `delivery`
    # 
    # _@param_ `max_bytes_per_partition`
    # 
    # _@param_ `session_timeout`
    # 
    # _@param_ `offset_commit_interval`
    # 
    # _@param_ `heartbeat_interval`
    # 
    # _@param_ `offset_commit_threshold`
    # 
    # _@param_ `offset_retention_time`
    sig do
      params(
        handler: T.class_of(BasicObject),
        group_id: String,
        topic: String,
        min_bytes: T.nilable(Integer),
        max_wait_time: T.nilable(Integer),
        force_encoding: T.untyped,
        start_from_beginning: T::Boolean,
        backoff: T.untyped,
        delivery: String,
        max_bytes_per_partition: Integer,
        session_timeout: T.nilable(Integer),
        offset_commit_interval: T.nilable(Integer),
        heartbeat_interval: T.nilable(Integer),
        offset_commit_threshold: T.nilable(Integer),
        offset_retention_time: T.nilable(Integer)
      ).void
    end
    def initialize(handler:, group_id:, topic:, min_bytes: nil, max_wait_time: nil, force_encoding: nil, start_from_beginning: true, backoff: nil, delivery: 'batch', max_bytes_per_partition: DEFAULT_MAX_BYTES_PER_PARTITION, session_timeout: nil, offset_commit_interval: nil, heartbeat_interval: nil, offset_commit_threshold: nil, offset_retention_time: nil); end

    sig { void }
    def start; end

    sig { void }
    def stop; end

    sig { returns(T.untyped) }
    def create_exponential_backoff; end

    sig { returns(T::Boolean) }
    def should_stop?; end

    sig { returns(T.untyped) }
    def send_heartbeat_if_necessary; end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_info(msg, metadata = {}); end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_debug(msg, metadata = {}); end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_error(msg, metadata); end

    sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def log_warn(msg, metadata = {}); end

    sig { params(event: T.untyped, extra: T.untyped).returns(T.untyped) }
    def instrument(event, extra = {}); end

    sig { returns(String) }
    attr_reader :group_id

    sig { returns(String) }
    attr_reader :topic

    # Returns the value of attribute id.
    sig { returns(T.untyped) }
    attr_reader :id

    sig { returns(T.class_of(BasicObject)) }
    attr_reader :handler_class

    # Returns the value of attribute encoding.
    sig { returns(T.untyped) }
    attr_reader :encoding

    # Returns the value of attribute consumer.
    sig { returns(T.untyped) }
    attr_reader :consumer
  end

  module Producer
    sig { returns(Phobos::Producer::PublicAPI) }
    def producer; end

    class PublicAPI
      sig { params(host_obj: T.untyped).void }
      def initialize(host_obj); end

      # _@param_ `topic`
      # 
      # _@param_ `payload`
      # 
      # _@param_ `key`
      # 
      # _@param_ `partition_key`
      # 
      # _@param_ `headers`
      sig do
        params(
          topic: String,
          payload: String,
          key: T.nilable(String),
          partition_key: T.nilable(Integer),
          headers: T.nilable(T::Hash[T.untyped, T.untyped])
        ).void
      end
      def publish(topic:, payload:, key: nil, partition_key: nil, headers: nil); end

      # _@param_ `topic`
      # 
      # _@param_ `payload`
      # 
      # _@param_ `key`
      # 
      # _@param_ `partition_key`
      # 
      # _@param_ `headers`
      sig do
        params(
          topic: String,
          payload: String,
          key: T.nilable(String),
          partition_key: T.nilable(Integer),
          headers: T.nilable(T::Hash[T.untyped, T.untyped])
        ).void
      end
      def async_publish(topic:, payload:, key: nil, partition_key: nil, headers: nil); end

      # _@param_ `messages` — e.g.: [   { topic: 'A', payload: 'message-1', key: '1', headers: { foo: 'bar' } },   { topic: 'B', payload: 'message-2', key: '2', headers: { foo: 'bar' } } ]
      sig { params(messages: T::Array[T::Hash[T.untyped, T.untyped]]).returns(T.untyped) }
      def publish_list(messages); end

      # _@param_ `messages`
      sig { params(messages: T::Array[T::Hash[T.untyped, T.untyped]]).returns(T.untyped) }
      def async_publish_list(messages); end
    end

    module ClassMethods
      sig { returns(Phobos::Producer::ClassMethods::PublicAPI) }
      def producer; end

      class PublicAPI
        NAMESPACE = T.let(:phobos_producer_store, T.untyped)
        ASYNC_PRODUCER_PARAMS = T.let([:max_queue_size, :delivery_threshold, :delivery_interval].freeze, T.untyped)
        INTERNAL_PRODUCER_PARAMS = T.let([:persistent_connections].freeze, T.untyped)

        # This method configures the kafka client used with publish operations
        # performed by the host class
        # 
        # _@param_ `kafka_client`
        sig { params(kafka_client: Kafka::Client).void }
        def configure_kafka_client(kafka_client); end

        sig { returns(Kafka::Client) }
        def kafka_client; end

        sig { returns(Kafka::Producer) }
        def create_sync_producer; end

        sig { returns(Kafka::Producer) }
        def sync_producer; end

        sig { void }
        def sync_producer_shutdown; end

        # _@param_ `topic`
        # 
        # _@param_ `payload`
        # 
        # _@param_ `partition_key`
        # 
        # _@param_ `headers`
        sig do
          params(
            topic: String,
            payload: String,
            key: T.untyped,
            partition_key: T.nilable(Integer),
            headers: T.nilable(T::Hash[T.untyped, T.untyped])
          ).void
        end
        def publish(topic:, payload:, key: nil, partition_key: nil, headers: nil); end

        # _@param_ `messages`
        sig { params(messages: T::Array[T::Hash[T.untyped, T.untyped]]).void }
        def publish_list(messages); end

        sig { returns(Kafka::AsyncProducer) }
        def create_async_producer; end

        sig { returns(Kafka::AsyncProducer) }
        def async_producer; end

        # _@param_ `topic`
        # 
        # _@param_ `payload`
        # 
        # _@param_ `partition_key`
        # 
        # _@param_ `headers`
        sig do
          params(
            topic: String,
            payload: String,
            key: T.untyped,
            partition_key: T.nilable(Integer),
            headers: T.nilable(T::Hash[T.untyped, T.untyped])
          ).void
        end
        def async_publish(topic:, payload:, key: nil, partition_key: nil, headers: nil); end

        # _@param_ `messages`
        sig { params(messages: T::Array[T::Hash[T.untyped, T.untyped]]).void }
        def async_publish_list(messages); end

        sig { void }
        def async_producer_shutdown; end

        sig { returns(T::Hash[T.untyped, T.untyped]) }
        def regular_configs; end

        sig { returns(T::Hash[T.untyped, T.untyped]) }
        def async_configs; end
      end
    end
  end

  module Constants
    LOG_DATE_PATTERN = T.let('%Y-%m-%dT%H:%M:%S:%L%zZ', T.untyped)
    KAFKA_CONSUMER_OPTS = T.let([
  :session_timeout,
  :offset_commit_interval,
  :offset_commit_threshold,
  :heartbeat_interval,
  :offset_retention_time
].freeze, T.untyped)
    LISTENER_OPTS = T.let([
  :handler,
  :group_id,
  :topic,
  :min_bytes,
  :max_wait_time,
  :force_encoding,
  :start_from_beginning,
  :max_bytes_per_partition,
  :backoff,
  :delivery,
  :session_timeout,
  :offset_commit_interval,
  :offset_commit_threshold,
  :heartbeat_interval,
  :offset_retention_time
].freeze, T.untyped)
  end

  module Processor
    include Phobos::Instrumentation
    extend ActiveSupport::Concern
    MAX_SLEEP_INTERVAL = T.let(3, T.untyped)

    sig { params(interval: T.untyped).returns(T.untyped) }
    def snooze(interval); end

    sig { params(event: T.untyped, extra: T.untyped).returns(T.untyped) }
    def instrument(event, extra = {}); end
  end

  class DeepStruct < OpenStruct
    # Based on
    # https://docs.omniref.com/ruby/2.3.0/files/lib/ostruct.rb#line=88
    sig { params(hash: T.untyped).void }
    def initialize(hash = nil); end

    sig { returns(T.untyped) }
    def to_h; end
  end

  module Test
    module Helper
      TOPIC = T.let('test-topic', T.untyped)
      GROUP = T.let('test-group', T.untyped)

      sig do
        params(
          handler: T.untyped,
          payload: T.untyped,
          metadata: T.untyped,
          force_encoding: T.untyped
        ).returns(T.untyped)
      end
      def process_message(handler:, payload:, metadata: {}, force_encoding: nil); end
    end
  end

  class EchoHandler
    include Phobos::Handler

    sig { params(message: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def consume(message, metadata); end

    sig { params(payload: T.untyped, metadata: T.untyped).returns(T.untyped) }
    def around_consume(payload, metadata); end
  end

  module BatchHandler
    # _@param_ `_payloads`
    # 
    # _@param_ `_metadata`
    sig { params(_payloads: T::Array[T.untyped], _metadata: T::Hash[String, Object]).void }
    def consume_batch(_payloads, _metadata); end

    # _@param_ `payloads`
    # 
    # _@param_ `metadata`
    sig { params(payloads: T::Array[T.untyped], metadata: T::Hash[String, Object]).void }
    def around_consume_batch(payloads, metadata); end

    module ClassMethods
      # _@param_ `kafka_client`
      sig { params(kafka_client: T.untyped).void }
      def start(kafka_client); end

      sig { void }
      def stop; end
    end
  end

  class BatchMessage
    # _@param_ `key`
    # 
    # _@param_ `partition`
    # 
    # _@param_ `offset`
    # 
    # _@param_ `payload`
    # 
    # _@param_ `headers`
    sig do
      params(
        key: T.untyped,
        partition: Integer,
        offset: Integer,
        payload: T.untyped,
        headers: T.untyped
      ).void
    end
    def initialize(key:, partition:, offset:, payload:, headers:); end

    # _@param_ `other`
    sig { params(other: Phobos::BatchMessage).returns(T::Boolean) }
    def ==(other); end

    sig { returns(T.untyped) }
    attr_accessor :key

    sig { returns(Integer) }
    attr_accessor :partition

    sig { returns(Integer) }
    attr_accessor :offset

    sig { returns(T.untyped) }
    attr_accessor :payload

    sig { returns(T.untyped) }
    attr_accessor :headers
  end

  module Configuration
    # _@param_ `configuration`
    sig { params(configuration: T.untyped).void }
    def configure(configuration); end

    sig { void }
    def configure_logger; end
  end

  module Instrumentation
    NAMESPACE = T.let('phobos', T.untyped)

    sig { params(event: T.untyped).returns(T.untyped) }
    def self.subscribe(event); end

    sig { params(subscriber: T.untyped).returns(T.untyped) }
    def self.unsubscribe(subscriber); end

    sig { params(event: T.untyped, extra: T.untyped).returns(T.untyped) }
    def instrument(event, extra = {}); end
  end

  module Actions
    class ProcessBatch
      include Phobos::Instrumentation
      include Phobos::Log

      sig { params(listener: T.untyped, batch: T.untyped, listener_metadata: T.untyped).void }
      def initialize(listener:, batch:, listener_metadata:); end

      sig { returns(T.untyped) }
      def execute; end

      sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
      def log_info(msg, metadata = {}); end

      sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
      def log_debug(msg, metadata = {}); end

      sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
      def log_error(msg, metadata); end

      sig { params(msg: T.untyped, metadata: T.untyped).returns(T.untyped) }
      def log_warn(msg, metadata = {}); end

      sig { params(event: T.untyped, extra: T.untyped).returns(T.untyped) }
      def instrument(event, extra = {}); end

      # Returns the value of attribute metadata.
      sig { returns(T.untyped) }
      attr_reader :metadata
    end

    class ProcessMessage
      include Phobos::Processor

      sig { params(listener: T.untyped, message: T.untyped, listener_metadata: T.untyped).void }
      def initialize(listener:, message:, listener_metadata:); end

      sig { returns(T.untyped) }
      def execute; end

      sig { params(interval: T.untyped).returns(T.untyped) }
      def snooze(interval); end

      sig { params(event: T.untyped, extra: T.untyped).returns(T.untyped) }
      def instrument(event, extra = {}); end

      # Returns the value of attribute metadata.
      sig { returns(T.untyped) }
      attr_reader :metadata
    end

    class ProcessBatchInline
      include Phobos::Processor

      sig { params(listener: T.untyped, batch: T.untyped, metadata: T.untyped).void }
      def initialize(listener:, batch:, metadata:); end

      sig { returns(T.untyped) }
      def execute; end

      sig { params(interval: T.untyped).returns(T.untyped) }
      def snooze(interval); end

      sig { params(event: T.untyped, extra: T.untyped).returns(T.untyped) }
      def instrument(event, extra = {}); end

      # Returns the value of attribute metadata.
      sig { returns(T.untyped) }
      attr_reader :metadata
    end
  end
end
