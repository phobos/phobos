module Phobos
  class EchoHandler
    include Phobos::Handler

    def consume(message, metadata)
      Phobos.logger.info { Hash(message: 'Echo handler consuming message').merge(metadata) }
    end
  end
end
