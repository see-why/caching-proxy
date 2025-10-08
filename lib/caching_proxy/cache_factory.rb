# frozen_string_literal: true

require_relative 'cache'
require_relative 'persistent_cache'
require 'logger'

module CachingProxy
  class CacheFactory
    SUPPORTED_BACKENDS = %w[memory redis sqlite].freeze

    # Error information for when cache creation fails
    class CacheCreationResult
      attr_reader :cache, :backend_used, :error_message, :fallback_used

      def initialize(cache, backend_used, error_message = nil, fallback_used = false)
        @cache = cache
        @backend_used = backend_used
        @error_message = error_message
        @fallback_used = fallback_used
      end

      def success?
        error_message.nil?
      end

      def fallback?
        fallback_used
      end
    end

    def self.create(backend = 'memory', options = {})
      backend = backend.to_s.downcase
      logger = options[:logger] || default_logger

      unless SUPPORTED_BACKENDS.include?(backend)
        raise ArgumentError, "Unsupported cache backend: #{backend}. Supported: #{SUPPORTED_BACKENDS.join(', ')}"
      end

      begin
        cache = case backend
                when 'memory'
                  Cache.new(options[:default_ttl])
                when 'redis'
                  require_relative 'redis_cache'
                  RedisCache.new(options[:redis_url], options[:default_ttl], logger: logger)
                when 'sqlite'
                  require_relative 'sqlite_cache'
                  SqliteCache.new(options[:database_path], options[:default_ttl], logger: logger)
                end

        CacheCreationResult.new(cache, backend)
      rescue LoadError => e
        error_message = case backend
                       when 'redis'
                         "Redis gem not available. Install with: gem install redis"
                       when 'sqlite'
                         "SQLite3 gem not available. Install with: gem install sqlite3"
                       else
                         "Required gem not available: #{e.message}"
                       end

        logger.warn("CacheFactory: #{error_message}. Falling back to memory cache.")
        fallback_cache = Cache.new(options[:default_ttl])
        CacheCreationResult.new(fallback_cache, 'memory', error_message, true)
      rescue => e
        error_message = "Error initializing #{backend} cache: #{e.message}"
        logger.warn("CacheFactory: #{error_message}. Falling back to memory cache.")

        fallback_cache = Cache.new(options[:default_ttl])
        CacheCreationResult.new(fallback_cache, 'memory', error_message, true)
      end
    end

    # Convenience method that returns just the cache (for backward compatibility)
    def self.create_cache(backend = 'memory', options = {})
      result = create(backend, options)
      result.cache
    end

    private

    def self.default_logger
      @default_logger ||= begin
        logger = Logger.new($stderr)
        logger.level = Logger::WARN
        logger.formatter = proc do |severity, datetime, progname, msg|
          "#{severity}: #{msg}\n"
        end
        logger
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
