# frozen_string_literal: true

module CachingProxy
  class Cache
    DEFAULT_TTL = 300 # seconds

    def initialize(default_ttl = DEFAULT_TTL)
      @store = {}
      @default_ttl = default_ttl
    end

    def key?(key)
      entry = @store[key]
      return false unless entry

      !expired?(entry)
    end

    def get(key)
      entry = @store[key]
      return nil unless entry
      return nil if expired?(entry)
      entry[:value]
    end

    def set(key, value, ttl = nil)
      ttl ||= @default_ttl
      @store[key] = {
        value: value,
        expires_at: Time.now + ttl
      }
    end

    def invalidate(key)
      @store.delete(key)
    end

    def clear
      @store.clear
    end

    private

    def expired?(entry)
      Time.now > entry[:expires_at]
    end
  end
end
