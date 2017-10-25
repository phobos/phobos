module Phobos
  module SpecHelper
    def process_message(handler, payload, metadata)
      listener = Phobos::Listener.new(handler: handler, group_id: 'test-group', topic: 'test-topic')
      message = OpenStruct.new(value: payload)
      listener.send(:process_message, message, metadata)
    end
  end
end
