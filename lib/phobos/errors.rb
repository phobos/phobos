# frozen_string_literal: true

module Phobos
  class Error < StandardError; end
  class AbortError < Error; end
  class InvalidHandlerError < Error; end
end
