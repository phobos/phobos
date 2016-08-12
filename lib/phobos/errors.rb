module Phobos
  class Error < StandardError; end
  class AbortError < Error; end
  class AsyncProducerNotConfiguredError < Error; end
end
