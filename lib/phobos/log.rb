# frozen_string_literal: true

module Phobos
  module Log
    def log_info(msg, metadata = {})
      LoggerHelper.log(:info, msg, metadata)
    end

    def log_debug(msg, metadata = {})
      LoggerHelper.log(:debug, msg, metadata)
    end

    def log_error(msg, metadata)
      LoggerHelper.log(:error, msg, metadata)
    end

    def log_warn(msg, metadata = {})
      LoggerHelper.log(:warn, msg, metadata)
    end
  end

  module LoggerHelper
    def self.log(method, msg, metadata)
      Phobos.logger.send(method, Hash(message: msg).merge(metadata))
    end
  end
end
