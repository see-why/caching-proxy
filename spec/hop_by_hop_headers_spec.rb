# frozen_string_literal: true

require_relative '../lib/caching_proxy/server'
require_relative '../lib/caching_proxy/cache'

RSpec.describe 'CachingProxy::Server Hop-by-Hop Header Filtering' do
  let(:origin) { 'http://example.com' }
  let(:cache) { CachingProxy::Cache.new(300) }
  let(:server) { CachingProxy::Server.new(origin, cache) }

  def build_mock_response(headers: {}, code: '200', body: 'body')
    response = double('response', code: code, body: body)
    allow(response).to receive(:each_header) do |&block|
      headers.each { |k, v| block.call(k, v) }
    end
    response
  end

  def rack_env_with_headers(headers: {}, method: 'GET', path: '/test')
    env = {
      'REQUEST_METHOD' => method,
      'PATH_INFO' => path,
      'QUERY_STRING' => '',
      'rack.input' => StringIO.new('')
    }

    # Add HTTP headers in Rack format
    headers.each do |name, value|
      rack_header = "HTTP_#{name.tr('-', '_').upcase}"
      env[rack_header] = value
    end

    env
  end

  before do
    allow_any_instance_of(Net::HTTP).to receive(:use_ssl=)
  end

  describe 'request header filtering' do
    it 'filters out hop-by-hop headers when forwarding requests' do
      hop_by_hop_headers = {
        'Connection' => 'keep-alive',
        'Keep-Alive' => 'timeout=5',
        'Proxy-Authorization' => 'Basic xyz',
        'TE' => 'trailers',
        'Trailers' => 'X-Custom',
        'Transfer-Encoding' => 'chunked',
        'Upgrade' => 'websocket'
      }

      regular_headers = {
        'User-Agent' => 'Test Agent',
        'Accept' => 'application/json',
        'Authorization' => 'Bearer token123'
      }

      all_headers = hop_by_hop_headers.merge(regular_headers)

      # Mock Net::HTTP to capture the request that gets sent
      captured_request = nil
      allow_any_instance_of(Net::HTTP).to receive(:request) do |http, request|
        captured_request = request
        build_mock_response
      end

      server.call(rack_env_with_headers(headers: all_headers))

      # Verify hop-by-hop headers were NOT forwarded
      hop_by_hop_headers.each do |header, _value|
        expect(captured_request[header]).to be_nil, "Expected #{header} to be filtered out"
      end

      # Verify regular headers WERE forwarded
      regular_headers.each do |header, value|
        expect(captured_request[header]).to eq(value), "Expected #{header} to be forwarded"
      end
    end

    it 'filters out HOST header (handled by Net::HTTP)' do
      headers = { 'Host' => 'custom-host.com' }

      captured_request = nil
      allow_any_instance_of(Net::HTTP).to receive(:request) do |http, request|
        captured_request = request
        build_mock_response
      end

      server.call(rack_env_with_headers(headers: headers))

      expect(captured_request['Host']).to be_nil
    end

    it 'preserves content headers for POST requests' do
      headers = {
        'Content-Type' => 'application/json',
        'Content-Length' => '123'
      }

      env = rack_env_with_headers(headers: headers, method: 'POST')
      env['CONTENT_TYPE'] = 'application/json'
      env['CONTENT_LENGTH'] = '123'

      captured_request = nil
      allow_any_instance_of(Net::HTTP).to receive(:request) do |http, request|
        captured_request = request
        build_mock_response
      end

      server.call(env)

      expect(captured_request['Content-Type']).to eq('application/json')
      expect(captured_request['Content-Length']).to eq('123')
    end
  end

  describe 'response header filtering' do
    it 'filters out hop-by-hop headers from origin response' do
      origin_headers = {
        'content-type' => 'application/json',
        'content-length' => '100',
        'connection' => 'close',
        'keep-alive' => 'timeout=5',
        'proxy-authenticate' => 'Basic realm="test"',
        'te' => 'gzip',
        'trailers' => 'X-Custom-Trailer',
        'transfer-encoding' => 'chunked',
        'upgrade' => 'h2c',
        'x-custom-header' => 'custom-value'
      }

      allow_any_instance_of(Net::HTTP).to receive(:request) do
        build_mock_response(headers: origin_headers)
      end

      _status, headers, _body = server.call(rack_env_with_headers)

      # Verify hop-by-hop headers were filtered out
      expect(headers['connection']).to be_nil
      expect(headers['keep-alive']).to be_nil
      expect(headers['proxy-authenticate']).to be_nil
      expect(headers['te']).to be_nil
      expect(headers['trailers']).to be_nil
      expect(headers['transfer-encoding']).to be_nil
      expect(headers['upgrade']).to be_nil

      # Verify regular headers were preserved
      expect(headers['content-type']).to eq('application/json')
      expect(headers['content-length']).to eq('100')
      expect(headers['x-custom-header']).to eq('custom-value')

      # Verify cache status header was added
      expect(headers['X-Cache']).not_to be_nil
    end

    it 'handles case-insensitive hop-by-hop header filtering' do
      origin_headers = {
        'Connection' => 'close',          # Pascal case
        'TRANSFER-ENCODING' => 'chunked', # Upper case
        'keep-alive' => 'timeout=5',      # Lower case
        'Te' => 'gzip'                    # Mixed case
      }

      allow_any_instance_of(Net::HTTP).to receive(:request) do
        build_mock_response(headers: origin_headers)
      end

      _status, headers, _body = server.call(rack_env_with_headers)

      # All variations should be filtered out
      expect(headers['Connection']).to be_nil
      expect(headers['TRANSFER-ENCODING']).to be_nil
      expect(headers['keep-alive']).to be_nil
      expect(headers['Te']).to be_nil
    end
  end

  describe 'edge cases' do
    it 'handles empty header values' do
      headers = {
        'Connection' => '',
        'User-Agent' => 'Test'
      }

      captured_request = nil
      allow_any_instance_of(Net::HTTP).to receive(:request) do |http, request|
        captured_request = request
        build_mock_response
      end

      server.call(rack_env_with_headers(headers: headers))

      expect(captured_request['Connection']).to be_nil
      expect(captured_request['User-Agent']).to eq('Test')
    end

    it 'handles nil header values gracefully' do
      # This shouldn't normally happen but let's be defensive
      allow_any_instance_of(Net::HTTP).to receive(:request) do
        response = build_mock_response
        allow(response).to receive(:each_header) do |&block|
          block.call('connection', nil)
          block.call('content-type', 'application/json')
        end
        response
      end

      expect { server.call(rack_env_with_headers) }.not_to raise_error
    end
  end
end
