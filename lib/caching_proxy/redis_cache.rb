# frozen_string_literal: true

require_relative 'persistent_cache'
require 'logger'

module CachingProxy
  class RedisCache < PersistentCache
    def initialize(redis_url = nil, default_ttl = DEFAULT_TTL, logger: nil)
      super(default_ttl)
      @logger = logger || default_logger

      begin
        require 'redis'
      rescue LoadError
        raise LoadError, "Redis gem not found. Add 'gem \"redis\"' to your Gemfile"
      end

      @redis = Redis.new(url: redis_url || ENV['REDIS_URL'] || 'redis://localhost:6379')
      @key_prefix = 'caching_proxy:'

      # Test connection
      @redis.ping
      @logger.info("RedisCache: Successfully connected to Redis at #{get_redis_connection_info}")
    rescue Redis::CannotConnectError => e
      raise "Cannot connect to Redis: #{e.message}"
    end

    def key?(key)
      @redis.exists?("#{@key_prefix}#{key}") > 0
    end

    def get(key)
      raw_value = @redis.get("#{@key_prefix}#{key}")
      return nil unless raw_value

      deserialize_value(raw_value)
    rescue JSON::ParserError
      # Handle legacy or corrupted data
      invalidate(key)
      nil
    end

    def set(key, value, ttl = nil)
      ttl ||= @default_ttl
      serialized_value = serialize_value(value)

      if ttl > 0
        @redis.setex("#{@key_prefix}#{key}", ttl, serialized_value)
      else
        @redis.set("#{@key_prefix}#{key}", serialized_value)
      end
    end

    def invalidate(key)
      @redis.del("#{@key_prefix}#{key}") > 0
    end

    def invalidate_pattern(pattern)
      full_pattern = "#{@key_prefix}#{pattern}"
      keys_to_delete = @redis.keys(full_pattern)

      return [] if keys_to_delete.empty?

      @redis.del(*keys_to_delete)
      # Remove prefix from returned keys
      keys_to_delete.map { |key| key.sub(@key_prefix, '') }
    end

    def keys
      all_keys = @redis.keys("#{@key_prefix}*")
      # Remove prefix from keys
      all_keys.map { |key| key.sub(@key_prefix, '') }
    end

    def size
      @redis.dbsize
    end

    def clear
      # Only clear keys with our prefix to avoid affecting other applications
      pattern_keys = @redis.keys("#{@key_prefix}*")
      return 0 if pattern_keys.empty?

      @redis.del(*pattern_keys)
    end

    def stats
      info = @redis.info
      super.merge({
        redis_version: info['redis_version'],
        used_memory: info['used_memory_human'],
        connected_clients: info['connected_clients'],
        total_commands_processed: info['total_commands_processed'],
        keyspace_hits: info['keyspace_hits'],
        keyspace_misses: info['keyspace_misses']
      })
    end

    def close
      @redis&.quit
    rescue Redis::ConnectionError
      # Connection already closed
    end

    private

    def get_redis_connection_info
      # Safely extract connection information from Redis client
      begin
        # Try to get connection info from the client's public API
        if @redis.respond_to?(:connection) && @redis.connection.respond_to?(:fetch)
          host = @redis.connection.fetch(:host, 'unknown')
          port = @redis.connection.fetch(:port, 'unknown')
          "#{host}:#{port}"
        elsif @redis.respond_to?(:connection) && @redis.connection.is_a?(Hash)
          host = @redis.connection[:host] || @redis.connection['host'] || 'unknown'
          port = @redis.connection[:port] || @redis.connection['port'] || 'unknown'
          "#{host}:#{port}"
        else
          # Fallback: try to extract from Redis ID or use generic message
          @redis.respond_to?(:id) ? @redis.id : 'Redis server'
        end
      rescue => e
        # If all else fails, return a generic message
        "Redis server (connection details unavailable: #{e.message})"
      end
    end

    def default_logger
      @default_logger ||= begin
        logger = Logger.new($stderr)
        logger.level = Logger::INFO
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{severity}: #{msg}\n"
        end
        logger
      end
    end

    def serialize_value(value)
      # Store metadata along with value for better debugging
      data = {
        value: value,
        stored_at: Time.now.to_f,
        version: '1.0'
      }
      super(data)
    end

    def deserialize_value(serialized_value)
      data = super(serialized_value)
      # Handle both new format (with metadata) and legacy format
      if data.is_a?(Hash) && data.key?('value')
        data['value']
      else
        data
      end
    end
  end
end
