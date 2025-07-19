# frozen_string_literal: true

module CachingProxy
  class Cache
    def initialize
      @store = {}
    end

    def key?(key)
      @store.key? key
    end

    def get(key)
      @store[key]
    end

    def set(key, value)
      @store[key] = response
    end

    def clear
      @store.clear
    end
  end
end
