# frozen_string_literal: true

require_relative '../lib/caching_proxy/server'
require_relative '../lib/caching_proxy/cache'

RSpec.describe 'CachingProxy::Server Resource ID Patterns' do
  let(:origin) { 'http://example.com' }
  let(:cache) { CachingProxy::Cache.new(300) }
  let(:server) { CachingProxy::Server.new(origin, cache) }

  def build_stub_response(code: '200', body: 'body')
    response = double('response', code: code, body: body)
    allow(response).to receive(:each_header)
    response
  end

  def rack_env(method: 'PUT', path: '/users/123')
    {
      'REQUEST_METHOD' => method,
      'PATH_INFO' => path,
      'QUERY_STRING' => '',
      'rack.input' => StringIO.new('')
    }
  end

  before do
    allow_any_instance_of(Net::HTTP).to receive(:use_ssl=)
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(build_stub_response)
  end

  describe 'default resource ID pattern' do
    it 'detects numeric IDs' do
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users/123')
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users*')
      server.call(rack_env(path: '/users/123'))
    end

    it 'detects alphanumeric IDs' do
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users/abc123')
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users*')
      server.call(rack_env(path: '/users/abc123'))
    end

    it 'detects IDs with underscores' do
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users/user_123')
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users*')
      server.call(rack_env(path: '/users/user_123'))
    end

    it 'detects IDs with hyphens' do
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users/user-123')
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users*')
      server.call(rack_env(path: '/users/user-123'))
    end

    it 'detects UUID-like IDs' do
      uuid = '123e4567-e89b-12d3-a456-426614174000'
      expect(cache).to receive(:invalidate_pattern).with("GET:http://example.com/users/#{uuid}")
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users*')
      server.call(rack_env(path: "/users/#{uuid}"))
    end

    it 'detects IDs with trailing slash' do
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users/123/')
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users*')
      server.call(rack_env(path: '/users/123/'))
    end

    it 'does not detect collection URLs as having IDs' do
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users')
      expect(cache).not_to receive(:invalidate_pattern).with('GET:http://example.com*')
      server.call(rack_env(path: '/users'))
    end

    it 'does not detect URLs ending with special characters' do
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users/search?')
      expect(cache).not_to receive(:invalidate_pattern).with(match(/users\*/))
      server.call(rack_env(path: '/users/search?'))
    end

    it 'does not detect simple collection names as IDs' do
      %w[/users /posts /comments /admin /api].each do |path|
        expect(cache).to receive(:invalidate_pattern).with("GET:http://example.com#{path}")
        expect(cache).not_to receive(:invalidate_pattern).with(match(/\*/))
        server.call(rack_env(path: path))
      end
    end

    it 'detects various real-world ID formats' do
      test_ids = [
        'user123',        # Simple alphanumeric
        '123abc',         # Number then letters
        'usr_123',        # Underscore separator
        'post-456',       # Hyphen separator
        'item_abc_123',   # Multiple underscores
        'doc-v2-final',   # Multiple hyphens
        '2023_report_v1'  # Complex mix
      ]

      test_ids.each do |id|
        expect(cache).to receive(:invalidate_pattern).with("GET:http://example.com/items/#{id}")
        expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/items*')
        server.call(rack_env(path: "/items/#{id}"))
      end
    end
  end

  describe 'custom resource ID pattern' do
    let(:custom_pattern) { %r{/[0-9]+/?$} } # Only numeric IDs
    let(:server) { CachingProxy::Server.new(origin, cache, resource_id_pattern: custom_pattern) }

    it 'uses custom pattern for numeric IDs' do
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users/123')
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users*')
      server.call(rack_env(path: '/users/123'))
    end

    it 'does not match alphanumeric IDs with custom numeric-only pattern' do
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users/abc123')
      expect(cache).not_to receive(:invalidate_pattern).with('GET:http://example.com/users*')
      server.call(rack_env(path: '/users/abc123'))
    end
  end

  describe 'DELETE method with different ID formats' do
    it 'invalidates cache for DELETE with UUID' do
      uuid = '550e8400-e29b-41d4-a716-446655440000'
      expect(cache).to receive(:invalidate_pattern).with("GET:http://example.com/posts/#{uuid}")
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/posts*')
      server.call(rack_env(method: 'DELETE', path: "/posts/#{uuid}"))
    end

    it 'invalidates cache for DELETE with alphanumeric ID' do
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/posts/post_abc123')
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/posts*')
      server.call(rack_env(method: 'DELETE', path: '/posts/post_abc123'))
    end
  end
end
