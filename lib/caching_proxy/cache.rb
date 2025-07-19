# frozen_string_literal: true

module CachingProxy
  attr_reader :store
  class Cache
    def initialize
      @store = {}
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
