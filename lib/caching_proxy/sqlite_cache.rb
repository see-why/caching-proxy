# frozen_string_literal: true

require_relative 'persistent_cache'
require 'logger'

module CachingProxy
  class SqliteCache < PersistentCache
    def initialize(database_path = nil, default_ttl = DEFAULT_TTL, logger: nil)
      super(default_ttl)
      @logger = logger || default_logger

      begin
        require 'sqlite3'
      rescue LoadError
        raise LoadError, "SQLite3 gem not found. Add 'gem \"sqlite3\"' to your Gemfile"
      end

      @database_path = database_path || ENV['CACHE_DATABASE_PATH'] || 'cache.db'
      @db = SQLite3::Database.new(@database_path)
      @db.results_as_hash = true

      create_table
      @logger.info("SqliteCache: Using SQLite cache database: #{@database_path}")
    end

    def key?(key)
      cleanup_expired
      result = @db.get_first_value(
        "SELECT COUNT(*) FROM cache_entries WHERE key = ? AND (expires_at IS NULL OR expires_at > ?)",
        [key, Time.now.to_f]
      )
      result > 0
    end

    def get(key)
      cleanup_expired
      row = @db.get_first_row(
        "SELECT value FROM cache_entries WHERE key = ? AND (expires_at IS NULL OR expires_at > ?)",
        [key, Time.now.to_f]
      )

      return nil unless row

      deserialize_value(row['value'])
    rescue JSON::ParserError
      # Handle corrupted data
      invalidate(key)
      nil
    end

    def set(key, value, ttl = nil)
      ttl ||= @default_ttl
      expires_at = ttl > 0 ? Time.now.to_f + ttl : nil
      serialized_value = serialize_value(value)

      @db.execute(
        "INSERT OR REPLACE INTO cache_entries (key, value, expires_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
        [key, serialized_value, expires_at, Time.now.to_f, Time.now.to_f]
      )
    end

    def invalidate(key)
      @db.execute("DELETE FROM cache_entries WHERE key = ?", [key])
      @db.changes > 0
    end

    def invalidate_pattern(pattern)
      # Convert shell pattern to SQL LIKE pattern
      sql_pattern = pattern.gsub('*', '%').gsub('?', '_')

      # Get keys before deleting for return value
      deleted_keys_rows = @db.execute(
        "SELECT key FROM cache_entries WHERE key LIKE ?",
        [sql_pattern]
      )

      # Delete the matching keys
      @db.execute("DELETE FROM cache_entries WHERE key LIKE ?", [sql_pattern])

      deleted_keys_rows.map { |row| row['key'] }
    end

    def keys
      cleanup_expired
      rows = @db.execute(
        "SELECT key FROM cache_entries WHERE expires_at IS NULL OR expires_at > ?",
        [Time.now.to_f]
      )
      rows.map { |row| row['key'] }
    end

    def size
      @db.get_first_value("SELECT COUNT(*) FROM cache_entries")
    end

    def clear
      @db.execute("DELETE FROM cache_entries")
      @db.changes
    end

    def stats
      total_keys = @db.get_first_value("SELECT COUNT(*) FROM cache_entries")
      active_keys = @db.get_first_value(
        "SELECT COUNT(*) FROM cache_entries WHERE expires_at IS NULL OR expires_at > ?",
        [Time.now.to_f]
      )
      expired_keys = total_keys - active_keys

      # Get database file size
      file_size = File.exist?(@database_path) ? File.size(@database_path) : 0

      super.merge({
        database_path: @database_path,
        database_size_bytes: file_size,
        database_size_human: human_readable_size(file_size),
        total_keys: total_keys,
        active_keys: active_keys,
        expired_keys: expired_keys
      })
    end

    def close
      @db&.close
    rescue SQLite3::Exception
      # Database already closed
    end

    # Maintenance method to clean up expired entries
    def cleanup_expired
      @db.execute("DELETE FROM cache_entries WHERE expires_at IS NOT NULL AND expires_at <= ?", [Time.now.to_f])
    end

    # Optimize database by running VACUUM
    def optimize
      @db.execute("VACUUM")
      @db.execute("ANALYZE")
    end

    private

    def create_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS cache_entries (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          expires_at REAL,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL
        )
      SQL

      # Create index for expiration queries
      @db.execute <<-SQL
        CREATE INDEX IF NOT EXISTS idx_cache_expires_at ON cache_entries(expires_at)
      SQL
    end

    def serialize_value(value)
      # Store metadata along with value
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

    def human_readable_size(bytes)
      units = ['B', 'KB', 'MB', 'GB', 'TB']
      size = bytes.to_f
      unit_index = 0

      while size >= 1024 && unit_index < units.length - 1
        size /= 1024
        unit_index += 1
      end

      "#{size.round(2)} #{units[unit_index]}"
    end
  end
end
