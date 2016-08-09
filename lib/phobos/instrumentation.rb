module Phobos
  module Instrumentation
    NAMESPACE = 'phobos'

    def instrument(event, extra = {})
      ActiveSupport::Notifications.instrument("#{NAMESPACE}.#{event}", extra) { yield if block_given? }
    end

    def self.subscribe(event)
      ActiveSupport::Notifications.subscribe("#{NAMESPACE}.#{event}") do |*args|
        yield ActiveSupport::Notifications::Event.new(*args) if block_given?
      end
    end

    def self.unsubscribe(subscriber)
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
