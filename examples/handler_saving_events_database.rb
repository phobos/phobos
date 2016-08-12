# Setup your database connection using `phobos_boot.rb`. Remeber to Setup
# a hook to disconnect, e.g: `at_exit { Database.disconnect! }`
#
class HandlerSavingEventsDatabase
  include Phobos::Handler
  include Phobos::Producer

  def self.around_consume(payload, metadata)
    # Let's assume `::from_message` will initialize our object with `payload`
    event = Model::Event.from_message(payload)

    # If event already exists in the database skip this message
    return if event.exists?

    Model::Event.transaction do
      # Executes `#consume` method
      new_values = yield

      # `#consume` method can return adicional data (up to your code)
      event.update_with_new_attributes(new_values)

      # Let's assume we just initialized the event and now is time to save
      event.save!
    end
  end

  def consume(payload, metadata)
    { new_vale: payload.length % 3 }
  end
end
