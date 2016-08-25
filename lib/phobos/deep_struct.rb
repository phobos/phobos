require 'ostruct'
module Phobos
  class DeepStruct < OpenStruct
    def initialize(hash=nil)
      @table = {}
      @hash_table = {}

      if hash
        hash.each_pair do |k, v|
          k = k.to_sym
          @table[k] = if v.is_a?(Hash)
            self.class.new(v)
          elsif v.is_a?(Array) && v.all? { |el| el.is_a?(Hash) }
            v.map { |el| self.class.new(el) }
          else
            v
          end

          @hash_table[k] = v
          new_ostruct_member(k)
        end
      end
    end

    def to_h
      @hash_table
    end

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
