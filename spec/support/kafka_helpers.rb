require 'securerandom'
require 'timeout'

module KafkaHelpers
  DEFAULT_TIMEOUT = 3
  @@subscriptions = Concurrent::Hash.new
  @@subscription_events = Concurrent::Hash.new

  def random
    %w(a b c d e f g h i j k l m n o p q r s t u v w x y z).sample(6).join
  end

  def random_topic(namespace = 'test')
    "#{namespace}-#{random}"
  end

  def random_group_id
    "testgroup_id-#{random}"
  end

  def create_topic(name, partitions: 2)
    `TOPIC=#{name} PARTITIONS=#{partitions} sh utils/create-topic.sh`
  end

  def events_for(name)
    @@subscription_events[name].tap do |events|
      raise "Not subscribed to event '#{name}'" if events.nil?
    end
  end

  def subscribe_to(*names)
    names.each do |name|
      unsubscribe(name)
      @@subscription_events[name] = Concurrent::Array.new
      @@subscriptions[name] = Phobos::Instrumentation.subscribe(name) do |event|
        @@subscription_events[name] << event
      end
    end
    yield if block_given?
  end

  def unsubscribe(name)
    Phobos::Instrumentation.unsubscribe(@@subscriptions[name])
  end

  def unsubscribe_all
    @@subscriptions.each { |name| unsubscribe(name) }
  end

  def wait_for_event(name, amount: 1, timeout: DEFAULT_TIMEOUT)
    wait(timeout) { events_for(name).size == amount }

  rescue Timeout::Error
    label = amount > 1 ? 'events' : 'event'
    raise "Expected #{amount} #{label} '#{name}' in #{timeout}s but received #{@@subscription_events[name].size}"
  ensure
    unsubscribe(name)
  end

  def wait(timeout)
    Timeout.timeout(timeout) do
      loop { yield ? break : sleep(0.1) }
    end
  end
end
