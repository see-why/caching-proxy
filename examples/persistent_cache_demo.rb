#!/usr/bin/env ruby
# frozen_string_literal: true

# Database-Backed Cache Demo for Caching Proxy
# This script demonstrates persistent caching with Redis and SQLite

require_relative '../lib/caching_proxy/cache_factory'

puts "Database-Backed Cache Demo for Caching Proxy"
puts "=" * 50
puts

# Demo 1: Show available cache backends
puts "1. Available Cache Backends:"
backends = CachingProxy::CacheFactory.supported_backends
backends.each do |backend|
  info = CachingProxy::CacheFactory.backend_info[backend.to_sym]
  puts "   [#{backend.upcase}] #{info[:description]}"
  puts "     Persistent: #{info[:persistent] ? 'Yes' : 'No'}"
  puts "     Distributed: #{info[:distributed] ? 'Yes' : 'No'}"
  puts
end

# Demo 2: Memory Cache (baseline)
puts "2. Memory Cache (Baseline):"
memory_cache = CachingProxy::CacheFactory.create('memory', default_ttl: 300)
memory_cache.set('demo_key', 'demo_value')
puts "   Set 'demo_key' = 'demo_value'"
puts "   Get 'demo_key' = '#{memory_cache.get('demo_key')}'"
puts "   Persistent across restarts: No"
puts

# Demo 3: SQLite Cache
puts "3. SQLite Cache (Persistent, Single-Node):"
begin
  sqlite_cache = CachingProxy::CacheFactory.create('sqlite', database_path: 'demo_cache.db')

  # Set some data
  sqlite_cache.set('user:123:profile', { name: 'John Doe', email: 'john@example.com' })
  sqlite_cache.set('post:456:content', 'Hello World Blog Post', 3600) # 1 hour TTL

  puts "   Stored user profile and blog post"
  puts "   User profile: #{sqlite_cache.get('user:123:profile')}"
  puts "   Database path: demo_cache.db"

  # Show stats
  stats = sqlite_cache.stats
  puts "   Stats: #{stats[:total_keys]} keys, #{stats[:database_size_human]} on disk"

  sqlite_cache.close
  puts "   [Closed] Data persists in demo_cache.db"
rescue => e
  puts "   SQLite not available: #{e.message}"
end
puts

# Demo 4: Redis Cache
puts "4. Redis Cache (Persistent, Distributed):"
begin
  redis_cache = CachingProxy::CacheFactory.create('redis')

  # Set some data with different TTLs
  redis_cache.set('session:abc123', { user_id: 456, expires: Time.now + 3600 })
  redis_cache.set('api_cache:weather:nyc', { temp: 72, humidity: 65 }, 1800) # 30 min TTL

  puts "   Stored session and API cache data"
  puts "   Session data: #{redis_cache.get('session:abc123')}"

  # Show Redis-specific stats
  stats = redis_cache.stats
  puts "   Redis version: #{stats[:redis_version]}"
  puts "   Memory used: #{stats[:used_memory]}"

  redis_cache.close
  puts "   [Closed] Data persists in Redis server"
rescue => e
  puts "   Redis not available: #{e.message}"
end
puts

# Demo 5: Pattern invalidation
puts "5. Pattern Invalidation Demo:"
begin
  cache = CachingProxy::CacheFactory.create('sqlite', database_path: 'pattern_demo.db')

  # Set up test data
  cache.set('user:1:profile', 'User 1 Profile')
  cache.set('user:1:settings', 'User 1 Settings')
  cache.set('user:2:profile', 'User 2 Profile')
  cache.set('post:100:content', 'Post 100 Content')

  puts "   Created test data:"
  cache.keys.each { |key| puts "     - #{key}" }

  # Invalidate all user:1 data
  deleted = cache.invalidate_pattern('user:1:*')
  puts "   Invalidated pattern 'user:1:*': #{deleted.size} keys deleted"
  puts "   Remaining keys:"
  cache.keys.each { |key| puts "     - #{key}" }

  cache.close
rescue => e
  puts "   Pattern demo failed: #{e.message}"
end
puts

# Demo 6: CLI Usage Examples
puts "6. CLI Usage Examples:"
puts
puts "   [Memory] Default memory cache:"
puts "   $ ruby bin/caching_proxy.rb --port 8080 --origin https://httpbin.org"
puts
puts "   [SQLite] SQLite persistent cache:"
puts "   $ ruby bin/caching_proxy.rb --port 8080 --origin https://httpbin.org \\"
puts "     --cache-backend sqlite --cache-db /tmp/proxy_cache.db"
puts
puts "   [Redis] Redis distributed cache:"
puts "   $ ruby bin/caching_proxy.rb --port 8080 --origin https://httpbin.org \\"
puts "     --cache-backend redis --redis-url redis://localhost:6379/0"
puts
puts "   [TTL] Custom cache TTL (10 minutes):"
puts "   $ ruby bin/caching_proxy.rb --port 8080 --origin https://httpbin.org \\"
puts "     --cache-backend sqlite --cache-ttl 600"
puts

# Demo 7: Cache Management Commands
puts "7. Cache Management Commands:"
puts
puts "   [Info] Show available cache backends:"
puts "   $ ruby bin/caching_proxy.rb --cache-info"
puts
puts "   [Stats] Show cache statistics:"
puts "   $ ruby bin/caching_proxy.rb --cache-stats --cache-backend sqlite"
puts
puts "   [Clear] Clear all cached data:"
puts "   $ ruby bin/caching_proxy.rb --clear-cache --cache-backend redis"
puts
puts "   [Pattern] Invalidate cache pattern:"
puts "   $ ruby bin/caching_proxy.rb --invalidate-pattern 'user:*' --cache-backend sqlite"
puts

# Demo 8: Production Considerations
puts "8. Production Considerations:"
puts
puts "   [Performance] Redis vs SQLite:"
puts "   - Redis: Faster, in-memory, supports clustering"
puts "   - SQLite: Good for single-node, persistent, no extra infrastructure"
puts
puts "   [Backup] SQLite database files can be backed up:"
puts "   $ cp cache.db cache_backup_$(date +%Y%m%d).db"
puts
puts "   [Monitoring] Redis provides rich monitoring:"
puts "   $ redis-cli INFO memory"
puts "   $ redis-cli MONITOR"
puts
puts "   [Cleanup] SQLite supports optimization:"
puts "   # Automatic cleanup of expired entries"
puts "   # VACUUM and ANALYZE for performance"
puts

puts "[Done] Persistent cache demo completed!"
puts "Try running the proxy with --cache-backend sqlite or redis!"
puts "=" * 50

# Cleanup demo files
File.delete('demo_cache.db') if File.exist?('demo_cache.db')
File.delete('pattern_demo.db') if File.exist?('pattern_demo.db')
