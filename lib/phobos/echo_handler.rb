module Phobos
  class EchoHandler
    include Phobos::Handler

    def self.start(kafka_client)
      Phobos.logger.info { Hash(message: "Echo handler: start, received kafka_client: #{!!kafka_client}") }
    end

    def self.stop
      Phobos.logger.info { Hash(message: "Echo handler: stop") }
    end

    def self.around_consume(message, metadata)
      Phobos.logger.info { Hash(message: "Echo handler: before consume message").merge(metadata) }
      consumer_result = yield
      Phobos.logger.info { Hash(message: "Echo handler: after consume message, result: '#{consumer_result}'").merge(metadata) }
    end

    def consume(message, metadata)
      Phobos.logger.info { Hash(message: 'Echo handler: consuming message').merge(metadata) }
      :consume_result
    end
  end
end
