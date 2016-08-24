module Phobos
  class DeepStruct
    def self.extract(attrs)
      keys = attrs.keys
      Struct.new(*keys).new(*keys.map do |k|
        if attrs[k].is_a? Hash
          extract(attrs[k])
        elsif attrs[k].is_a?(Array) && attrs[k].all? { |el| el.is_a?(Hash) }
          attrs[k].map { |el| extract(el) }
        else
          attrs[k]
        end
      end)
    end
  end
end
