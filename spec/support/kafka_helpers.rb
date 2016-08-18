require 'securerandom'
require 'timeout'

module KafkaHelpers
  DEFAULT_TIMEOUT = ENV['DEFAULT_TIMEOUT'] ? ENV['DEFAULT_TIMEOUT'].to_i : 10

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
    `TOPIC=#{name} PARTITIONS=#{partitions} ./utils/create-topic.sh`
  end

  def events_for(name, ignore_errors: true)
    events = @@subscription_events[name]
    raise "Not subscribed to event '#{name}'" if events.nil?
    # removing events with errors inside
    if ignore_errors
      events.reject { |event| event.payload[:exception] }
    else
      events
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

  def wait_for_event(name, amount: 1, amount_gte: nil, ignore_errors: true, show_events_on_error: false, timeout: DEFAULT_TIMEOUT)
    operation = amount_gte ? :>= : :==
    amount = amount_gte ? amount_gte : amount

    wait(timeout) do
      events_for(name, ignore_errors: ignore_errors).size.public_send(operation, amount)
    end

  rescue Timeout::Error
    label = amount > 1 ? 'events' : 'event'
    total = events_for(name, ignore_errors: ignore_errors).size
    puts events_for(name, ignore_errors: false).map { |e| Hash[name, e.payload] } if show_events_on_error
    raise "Expected #{amount} #{label} '#{name}' in #{timeout}s but received #{total}"
  end

  def wait(timeout)
    Timeout.timeout(timeout) do
      loop { yield ? break : sleep(0.01) }
    end
  end
end
