# frozen_string_literal: true

module CachingProxy
  # Base interface for persistent cache backends
  class PersistentCache
    DEFAULT_TTL = 300 # seconds

    def initialize(default_ttl = DEFAULT_TTL)
      @default_ttl = default_ttl
    end

    # Abstract methods to be implemented by subclasses
    def key?(key)
      raise NotImplementedError, "Subclasses must implement #key?"
    end

    def get(key)
      raise NotImplementedError, "Subclasses must implement #get"
    end

    def set(key, value, ttl = nil)
      raise NotImplementedError, "Subclasses must implement #set"
    end

    def invalidate(key)
      raise NotImplementedError, "Subclasses must implement #invalidate"
    end

    def invalidate_pattern(pattern)
      raise NotImplementedError, "Subclasses must implement #invalidate_pattern"
    end

    def keys
      raise NotImplementedError, "Subclasses must implement #keys"
    end

    def size
      raise NotImplementedError, "Subclasses must implement #size"
    end

    def clear
      raise NotImplementedError, "Subclasses must implement #clear"
    end

    def stats
      {
        backend: self.class.name.split('::').last,
        total_keys: size,
        active_keys: keys.size
      }
    end

    def close
      # Default implementation - override if cleanup needed
    end

    protected

    def serialize_value(value)
      require 'json'
      JSON.generate(value)
    end

    def deserialize_value(serialized_value)
      require 'json'
      JSON.parse(serialized_value)
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
