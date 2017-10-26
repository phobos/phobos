module Phobos
  module Instrumentation
    NAMESPACE = 'phobos'

    def self.subscribe(event)
      ActiveSupport::Notifications.subscribe("#{NAMESPACE}.#{event}") do |*args|
        yield ActiveSupport::Notifications::Event.new(*args) if block_given?
      end
    end

    def self.unsubscribe(subscriber)
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    def instrument(event, extra = {})
      ActiveSupport::Notifications.instrument("#{NAMESPACE}.#{event}", extra) do |extra|
        yield(extra) if block_given?
      end
    end

    def measure
      start = Time.now.utc
      yield if block_given?
      (Time.now.utc - start).round(3)
    end
  end
end
