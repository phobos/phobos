module Phobos
  class DeepStruct < OpenStruct
    # Based on
    # https://docs.omniref.com/ruby/2.3.0/files/lib/ostruct.rb#line=88
    def initialize(hash=nil)
      @table = {}
      @hash_table = {}

      if hash
        hash.each_pair do |k, v|
          k = k.to_sym
          @hash_table[k] = v
          @table[k] = to_deep_struct(v)
        end
      end
    end

    def to_deep_struct(v)
      case v
      when Hash
        self.class.new(v)
      when Enumerable
        v.map { |el| to_deep_struct(el) }
      else
        v
      end
    end

    def to_h
      @hash_table.dup
    end
    alias_method :to_hash, :to_h
  end
end
