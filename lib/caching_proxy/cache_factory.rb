# frozen_string_literal: true

require_relative 'cache'
require_relative 'persistent_cache'

module CachingProxy
  class CacheFactory
    SUPPORTED_BACKENDS = %w[memory redis sqlite].freeze

    def self.create(backend = 'memory', options = {})
      backend = backend.to_s.downcase

      unless SUPPORTED_BACKENDS.include?(backend)
        raise ArgumentError, "Unsupported cache backend: #{backend}. Supported: #{SUPPORTED_BACKENDS.join(', ')}"
      end

      begin
        case backend
        when 'memory'
          Cache.new(options[:default_ttl])
        when 'redis'
          require_relative 'redis_cache'
          RedisCache.new(options[:redis_url], options[:default_ttl])
        when 'sqlite'
          require_relative 'sqlite_cache'
          SqliteCache.new(options[:database_path], options[:default_ttl])
        end
      rescue LoadError => e
        fallback_message = case backend
                          when 'redis'
                            "Redis gem not available. Install with: gem install redis\nFalling back to memory cache."
                          when 'sqlite'
                            "SQLite3 gem not available. Install with: gem install sqlite3\nFalling back to memory cache."
                          end

        puts "Warning: #{e.message}"
        puts fallback_message if fallback_message

        # Fallback to memory cache
        Cache.new(options[:default_ttl])
      rescue => e
        puts "Error initializing #{backend} cache: #{e.message}"
        puts "Falling back to memory cache."

        # Fallback to memory cache
        Cache.new(options[:default_ttl])
      end
    end

    def self.supported_backends
      available_backends = ['memory']

      begin
        require 'redis'
        available_backends << 'redis'
      rescue LoadError
        # Redis not available
      end

      begin
        require 'sqlite3'
        available_backends << 'sqlite'
      rescue LoadError
        # SQLite3 not available
      end

      available_backends
    end

    def self.backend_info
      {
        memory: {
          description: 'In-memory cache (default, fast but not persistent)',
          persistent: false,
          distributed: false,
          dependencies: []
        },
        redis: {
          description: 'Redis-backed cache (persistent and distributed)',
          persistent: true,
          distributed: true,
          dependencies: ['redis gem', 'Redis server']
        },
        sqlite: {
          description: 'SQLite-backed cache (persistent, single-node)',
          persistent: true,
          distributed: false,
          dependencies: ['sqlite3 gem']
        }
      }
    end
  end
end
