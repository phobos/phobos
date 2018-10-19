# frozen_string_literal: true

#
# This example assumes that you want to save all events in your database for
# recovery purposes. The consumer will process the message and perform other
# operations, this implementation assumes a generic way to save the events.
#
# Setup your database connection using `phobos_boot.rb`. Remember to Setup
# a hook to disconnect, e.g: `at_exit { Database.disconnect! }`
#
class HandlerSavingEventsDatabase
  include Phobos::Handler
  include Phobos::Producer

  def self.around_consume(payload, _metadata)
    #
    # Let's assume `::from_message` will initialize our object with `payload`
    #
    event = Model::Event.from_message(payload)

    #
    # If event already exists in the database, skip this message
    #
    return if event.exists?

    Model::Event.transaction do
      #
      # Executes `#consume` method
      #
      new_values = yield

      #
      # `#consume` method can return additional data (up to your code)
      #
      event.update_with_new_attributes(new_values)

      #
      # Let's assume the event is just initialized and now is the time to save it
      #
      event.save!
    end
  end

  def consume(payload, _metadata)
    #
    # Process the event, it might index it to elasticsearch or notify other
    # system, you should process your message inside this method.
    #
    { new_vale: payload.length % 3 }
  end
end
