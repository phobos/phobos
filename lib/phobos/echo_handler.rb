# frozen_string_literal: true

module Phobos
  class EchoHandler
    include Phobos::Handler

    def consume(message, metadata)
      Phobos.logger.info { Hash(message: message).merge(metadata) }
    end
  end
end
