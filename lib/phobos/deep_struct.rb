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
  end
end
