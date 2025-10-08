# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require_relative '../lib/caching_proxy/cache_factory'

RSpec.describe 'CachingProxy::CacheFactory' do
  describe '.create' do
    it 'creates memory cache by default' do
      result = CachingProxy::CacheFactory.create
      expect(result.cache).to be_a(CachingProxy::Cache)
      expect(result.backend_used).to eq('memory')
      expect(result.success?).to be true
      expect(result.fallback?).to be false
    end

    it 'creates memory cache when explicitly requested' do
      result = CachingProxy::CacheFactory.create('memory')
      expect(result.cache).to be_a(CachingProxy::Cache)
      expect(result.backend_used).to eq('memory')
      expect(result.success?).to be true
    end

    it 'accepts default_ttl option for memory cache' do
      result = CachingProxy::CacheFactory.create('memory', default_ttl: 600)
      result.cache.set('test', 'value')
      expect(result.cache.get('test')).to eq('value')
    end

    it 'falls back to memory cache when backend dependencies are missing' do
      # Mock the require call to simulate missing gem
      allow_any_instance_of(Object).to receive(:require).with('redis').and_raise(LoadError, "cannot load such file -- redis")

      result = CachingProxy::CacheFactory.create('redis')
      expect(result.cache).to be_a(CachingProxy::Cache) # Falls back to memory
      expect(result.backend_used).to eq('memory')
      expect(result.fallback?).to be true
      expect(result.error_message).to include('Redis gem not available')
    end

    it 'falls back to memory cache when backend connection fails' do
      # This test covers the Redis connection failure scenario
      result = CachingProxy::CacheFactory.create('redis')
      expect(result.cache).to be_a(CachingProxy::Cache) # Falls back to memory
      expect(result.backend_used).to eq('memory')
      expect(result.fallback?).to be true
      expect(result.error_message).to include('Error initializing redis cache')
    end

    it 'raises error for unsupported backend' do
      expect {
        CachingProxy::CacheFactory.create('unsupported')
      }.to raise_error(ArgumentError, /Unsupported cache backend/)
    end
  end

  describe '.create_cache' do
    it 'returns just the cache instance for backward compatibility' do
      cache = CachingProxy::CacheFactory.create_cache
      expect(cache).to be_a(CachingProxy::Cache)
    end

    it 'works with options' do
      cache = CachingProxy::CacheFactory.create_cache('memory', default_ttl: 600)
      expect(cache).to be_a(CachingProxy::Cache)
    end
  end

  describe '.supported_backends' do
    it 'always includes memory backend' do
      backends = CachingProxy::CacheFactory.supported_backends
      expect(backends).to include('memory')
    end

    it 'returns array of strings' do
      backends = CachingProxy::CacheFactory.supported_backends
      expect(backends).to be_an(Array)
      expect(backends.all? { |b| b.is_a?(String) }).to be true
    end
  end

  describe '.backend_info' do
    it 'returns hash with backend information' do
      info = CachingProxy::CacheFactory.backend_info
      expect(info).to be_a(Hash)
      expect(info).to have_key(:memory)
      expect(info).to have_key(:redis)
      expect(info).to have_key(:sqlite)
    end

    it 'includes required fields for each backend' do
      info = CachingProxy::CacheFactory.backend_info
      info.each do |_backend, details|
        expect(details).to have_key(:description)
        expect(details).to have_key(:persistent)
        expect(details).to have_key(:distributed)
        expect(details).to have_key(:dependencies)
      end
    end
  end
end

# Test SQLite cache if available
RSpec.describe 'CachingProxy::SqliteCache', if: defined?(SQLite3) do
  let(:temp_dir) { Dir.mktmpdir }
  let(:db_path) { File.join(temp_dir, 'test_cache.db') }
  let(:cache) { CachingProxy::CacheFactory.create_cache('sqlite', database_path: db_path) }

  after do
    cache.close if cache.respond_to?(:close)
    FileUtils.rm_rf(temp_dir)
  end

  it 'creates SQLite cache with custom database path' do
    expect(cache).to be_a(CachingProxy::SqliteCache)
    expect(File.exist?(db_path)).to be true
  end

  it 'persists data across cache instances' do
    cache.set('persistent_key', 'persistent_value')
    cache.close

    # Create new cache instance with same database
    new_cache = CachingProxy::CacheFactory.create_cache('sqlite', database_path: db_path)
    expect(new_cache.get('persistent_key')).to eq('persistent_value')
    new_cache.close
  end

  it 'supports TTL with expiration' do
    cache.set('ttl_key', 'ttl_value', 1)
    expect(cache.get('ttl_key')).to eq('ttl_value')

    sleep(1.1)
    expect(cache.get('ttl_key')).to be_nil
  end

  it 'handles pattern invalidation' do
    cache.set('user:1:profile', 'profile1')
    cache.set('user:2:profile', 'profile2')
    cache.set('post:1:content', 'content1')

    deleted_keys = cache.invalidate_pattern('user:*')
    expect(deleted_keys).to contain_exactly('user:1:profile', 'user:2:profile')
    expect(cache.get('post:1:content')).to eq('content1')
  end

  it 'provides detailed stats' do
    cache.set('key1', 'value1')
    cache.set('key2', 'value2')

    stats = cache.stats
    expect(stats[:backend]).to eq('SqliteCache')
    expect(stats[:total_keys]).to eq(2)
    expect(stats[:active_keys]).to eq(2)
    expect(stats).to have_key(:database_path)
    expect(stats).to have_key(:database_size_bytes)
  end

  it 'cleans up expired entries' do
    cache.set('expired_key', 'value', 0.1)
    sleep(0.2)

    cache.cleanup_expired
    expect(cache.size).to eq(0)
  end

  it 'handles database optimization' do
    cache.set('key1', 'value1')
    expect { cache.optimize }.not_to raise_error
  end
end

# Test Redis cache if available (mock Redis if not)
RSpec.describe 'CachingProxy::RedisCache' do
  let(:cache) { CachingProxy::CacheFactory.create_cache('redis', redis_url: 'redis://localhost:6379/15') }

  before do
    # Skip Redis tests if Redis is not available
    skip 'Redis not available' unless defined?(Redis)

    # Skip if can't connect to Redis
    begin
      Redis.new(url: 'redis://localhost:6379/15').ping
    rescue Redis::CannotConnectError
      skip 'Redis server not available'
    end
  end

  after do
    cache.clear if cache.respond_to?(:clear)
    cache.close if cache.respond_to?(:close)
  end

  it 'creates Redis cache' do
    expect(cache).to be_a(CachingProxy::RedisCache)
  end

  it 'persists data across cache instances' do
    cache.set('redis_persistent_key', 'redis_persistent_value')
    cache.close

    # Create new cache instance with same Redis database
    new_cache = CachingProxy::CacheFactory.create_cache('redis', redis_url: 'redis://localhost:6379/15')
    expect(new_cache.get('redis_persistent_key')).to eq('redis_persistent_value')
    new_cache.close
  end

  it 'supports TTL with expiration' do
    cache.set('redis_ttl_key', 'redis_ttl_value', 1)
    expect(cache.get('redis_ttl_key')).to eq('redis_ttl_value')

    sleep(1.1)
    expect(cache.get('redis_ttl_key')).to be_nil
  end

  it 'handles pattern invalidation with Redis patterns' do
    cache.set('api:v1:users', 'users_data')
    cache.set('api:v1:posts', 'posts_data')
    cache.set('api:v2:users', 'v2_users_data')

    deleted_keys = cache.invalidate_pattern('api:v1:*')
    expect(deleted_keys.size).to eq(2)
    expect(cache.get('api:v2:users')).to eq('v2_users_data')
  end

  it 'provides Redis-specific stats' do
    cache.set('redis_key1', 'value1')

    stats = cache.stats
    expect(stats[:backend]).to eq('RedisCache')
    expect(stats).to have_key(:redis_version)
    expect(stats).to have_key(:used_memory)
    expect(stats).to have_key(:connected_clients)
  end

  it 'handles connection cleanup' do
    expect { cache.close }.not_to raise_error
  end
end
