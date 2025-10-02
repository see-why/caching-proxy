# frozen_string_literal: true

require_relative '../lib/caching_proxy/server'
require_relative '../lib/caching_proxy/cache'

RSpec.describe 'CachingProxy::Server HTTP Methods' do
  let(:origin) { 'http://example.com' }
  let(:cache) { CachingProxy::Cache.new(300) }
  let(:server) { CachingProxy::Server.new(origin, cache) }

  def build_stub_response(code: '200', body: 'body', cache_control: nil)
    response = double('response', code: code, body: body)
    allow(response).to receive(:each_header) do |&block|
      block.call('cache-control', cache_control) if cache_control
    end
    response
  end

  def rack_env(method: 'GET', path: '/test', query: '', body: '')
    env = {
      'REQUEST_METHOD' => method,
      'PATH_INFO' => path,
      'QUERY_STRING' => query,
      'rack.input' => StringIO.new(body)
    }
    if body && !body.empty?
      env['CONTENT_LENGTH'] = body.length.to_s
      env['CONTENT_TYPE'] = 'application/json'
    end
    env
  end

  before do
    allow_any_instance_of(Net::HTTP).to receive(:use_ssl=)
  end

  describe 'GET requests' do
    it 'caches GET responses' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      expect(cache).to receive(:set).with('GET:http://example.com/test', anything, anything)
      status, headers, _ = server.call(rack_env(method: 'GET'))

      expect(status).to eq(200)
      expect(headers['X-Cache']).to eq('MISS')
    end
  end

  describe 'HEAD requests' do
    it 'caches HEAD responses' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      expect(cache).to receive(:set).with('HEAD:http://example.com/test', anything, anything)
      status, headers, _ = server.call(rack_env(method: 'HEAD'))

      expect(status).to eq(200)
      expect(headers['X-Cache']).to eq('MISS')
    end
  end

  describe 'POST requests' do
    it 'does not cache POST responses' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      expect(cache).not_to receive(:set)
      status, headers, _ = server.call(rack_env(method: 'POST', body: '{"data": "test"}'))

      expect(status).to eq(200)
      expect(headers['X-Cache']).to eq('UNCACHEABLE')
    end

    it 'invalidates related GET cache entries' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/test*')
      server.call(rack_env(method: 'POST', path: '/test'))
    end
  end

  describe 'PUT requests' do
    it 'does not cache PUT responses' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      expect(cache).not_to receive(:set)
      status, headers, _ = server.call(rack_env(method: 'PUT', body: '{"data": "updated"}'))

      expect(status).to eq(200)
      expect(headers['X-Cache']).to eq('UNCACHEABLE')
    end

    it 'invalidates related cache entries for resource updates' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users/1')
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users*')
      server.call(rack_env(method: 'PUT', path: '/users/1'))
    end
  end

  describe 'DELETE requests' do
    it 'does not cache DELETE responses' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      expect(cache).not_to receive(:set)
      status, headers, _ = server.call(rack_env(method: 'DELETE'))

      expect(status).to eq(200)
      expect(headers['X-Cache']).to eq('UNCACHEABLE')
    end

    it 'invalidates related cache entries' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users/1')
      expect(cache).to receive(:invalidate_pattern).with('GET:http://example.com/users*')
      server.call(rack_env(method: 'DELETE', path: '/users/1'))
    end
  end

  describe 'PATCH requests' do
    it 'does not cache PATCH responses' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      expect(cache).not_to receive(:set)
      status, headers, _ = server.call(rack_env(method: 'PATCH', body: '{"data": "patched"}'))

      expect(status).to eq(200)
      expect(headers['X-Cache']).to eq('UNCACHEABLE')
    end
  end

  describe 'OPTIONS requests' do
    it 'caches OPTIONS responses' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      expect(cache).to receive(:set).with('OPTIONS:http://example.com/test', anything, anything)
      status, headers, _ = server.call(rack_env(method: 'OPTIONS'))

      expect(status).to eq(200)
      expect(headers['X-Cache']).to eq('MISS')
    end
  end

  describe 'unsupported methods' do
    it 'returns 405 for unsupported methods' do
      status, _, body = server.call(rack_env(method: 'TRACE'))

      expect(status).to eq(405)
      expect(body).to eq(['Method Not Allowed'])
    end
  end

  describe 'cache key generation' do
    it 'includes HTTP method in cache key' do
      stub_response = build_stub_response
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)

      # GET and HEAD to same URL should have different cache keys
      expect(cache).to receive(:set).with('GET:http://example.com/test', anything, anything)
      server.call(rack_env(method: 'GET'))

      expect(cache).to receive(:set).with('HEAD:http://example.com/test', anything, anything)
      server.call(rack_env(method: 'HEAD'))
    end
  end
end
