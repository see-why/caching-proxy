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

    def invalidate_pattern(pattern)
      regex = pattern_to_regex(pattern)
      deleted_keys = []
      @store.keys.each do |key|
        if regex.match?(key)
          @store.delete(key)
          deleted_keys << key
        end
      end
      deleted_keys
    end

    def keys
      @store.keys.select { |key| key?(key) }
    end

    def size
      @store.size
    end

    def stats
      {
        total_keys: @store.size,
        active_keys: keys.size,
        expired_keys: @store.size - keys.size
      }
    end

    def clear
      @store.clear
    end

    private

    def expired?(entry)
      expires_at = entry[:expires_at]
      return true if expires_at.nil?
      Time.now > expires_at
    end

    def pattern_to_regex(pattern)
      # Convert shell-style wildcards to regex
      # * matches any characters
      # ? matches single character
      escaped = Regexp.escape(pattern)
      regex_pattern = escaped.gsub('\*', '.*').gsub('\?', '.')
      Regexp.new("^#{regex_pattern}$")
    end
  end
end
