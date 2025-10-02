# frozen_string_literal: true

require_relative '../lib/caching_proxy/server'
require_relative '../lib/caching_proxy/cache'
require 'json'

RSpec.describe 'CachingProxy::Server Admin Endpoints' do
  let(:origin) { 'http://example.com' }
  let(:cache) { CachingProxy::Cache.new(300) }
  let(:server) { CachingProxy::Server.new(origin, cache) }

  def admin_env(path, method = 'GET', query_string = '')
    {
      'REQUEST_METHOD' => method,
      'PATH_INFO' => path,
      'QUERY_STRING' => query_string
    }
  end

  before do
    cache.set('user:1', { name: 'Alice' })
    cache.set('user:2', { name: 'Bob' })
    cache.set('post:1', { title: 'Hello' })
  end

  describe 'GET /__cache__/stats' do
    it 'returns cache statistics' do
      status, headers, body = server.call(admin_env('/__cache__/stats'))
      expect(status).to eq(200)
      expect(headers['Content-Type']).to eq('application/json')

      response = JSON.parse(body.first)
      expect(response['total_keys']).to eq(3)
      expect(response['active_keys']).to eq(3)
    end
  end

  describe 'GET /__cache__/keys' do
    it 'returns all cache keys' do
      status, headers, body = server.call(admin_env('/__cache__/keys'))
      expect(status).to eq(200)
      expect(headers['Content-Type']).to eq('application/json')

      response = JSON.parse(body.first)
      expect(response['keys']).to include('user:1', 'user:2', 'post:1')
      expect(response['count']).to eq(3)
    end
  end

  describe 'POST /__cache__/clear' do
    it 'clears all cache entries' do
      status, _, body = server.call(admin_env('/__cache__/clear', 'POST'))
      expect(status).to eq(200)

      response = JSON.parse(body.first)
      expect(response['message']).to eq('Cache cleared successfully')
      expect(cache.size).to eq(0)
    end

    it 'returns 405 for non-POST requests' do
      status, _, _ = server.call(admin_env('/__cache__/clear', 'GET'))
      expect(status).to eq(405)
    end
  end

  describe 'POST /__cache__/invalidate' do
    it 'invalidates specific key' do
      status, _, body = server.call(admin_env('/__cache__/invalidate', 'POST', 'key=user:1'))
      expect(status).to eq(200)

      response = JSON.parse(body.first)
      expect(response['message']).to eq('Key invalidated successfully')
      expect(response['key']).to eq('user:1')
      expect(cache.get('user:1')).to be_nil
      expect(cache.get('user:2')).not_to be_nil
    end

    it 'invalidates keys by pattern' do
      status, _, body = server.call(admin_env('/__cache__/invalidate', 'POST', 'pattern=user:*'))
      expect(status).to eq(200)

      response = JSON.parse(body.first)
      expect(response['message']).to eq('2 keys invalidated')
      expect(response['pattern']).to eq('user:*')
      expect(response['deleted_keys']).to include('user:1', 'user:2')
      expect(cache.get('user:1')).to be_nil
      expect(cache.get('user:2')).to be_nil
      expect(cache.get('post:1')).not_to be_nil
    end

    it 'returns 400 when key or pattern is missing' do
      status, _, body = server.call(admin_env('/__cache__/invalidate', 'POST'))
      expect(status).to eq(400)
      expect(body.first).to eq('Missing key or pattern parameter')
    end

    it 'returns 405 for non-POST requests' do
      status, _, _ = server.call(admin_env('/__cache__/invalidate', 'GET'))
      expect(status).to eq(405)
    end
  end

  describe 'unknown admin endpoint' do
    it 'returns 404' do
      status, _, body = server.call(admin_env('/__cache__/unknown'))
      expect(status).to eq(404)
      expect(body.first).to eq('Admin endpoint not found')
    end
  end
end
