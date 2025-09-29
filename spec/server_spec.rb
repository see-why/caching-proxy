# frozen_string_literal: true

require_relative '../lib/caching_proxy/server'
require_relative '../lib/caching_proxy/cache'

RSpec.describe CachingProxy::Server do
  let(:origin) { 'http://example.com' }
  let(:cache) { CachingProxy::Cache.new(1) } # 1 second TTL for testing
  let(:server) { described_class.new(origin, cache) }

  def rack_env(path = '/test')
    {
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => path,
      'QUERY_STRING' => ''
    }
  end

  def build_stub_response(code: '200', body: 'body', cache_control: '')
    headers = { 'cache-control' => cache_control }
    double('response', code: code, body: body, each_header: ->(&b) { headers.each { |k, v| b.call(k, v) } })
  end

  before do
    allow_any_instance_of(Net::HTTP).to receive(:use_ssl=)
  end

  it 'does not cache when Cache-Control: no-store is present' do
    stub_response = build_stub_response(cache_control: 'no-store')
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)
    expect(cache).not_to receive(:set)
    status, headers, body = server.call(rack_env)
    expect(headers['X-Cache']).to eq('NO-STORE')
    expect(status).to eq(200)
    expect(body).to eq(['body'])
  end

  it 'uses max-age from Cache-Control for TTL' do
    stub_response = build_stub_response(cache_control: 'max-age=2')
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)
    expect(cache).to receive(:set).with(anything, anything, 2)
    server.call(rack_env)
  end

  it 'revalidates with origin when Cache-Control: no-cache is present' do
    stub_response = build_stub_response(cache_control: 'no-cache')
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)
    expect(cache).to receive(:set)
    status, headers, body = server.call(rack_env)
    expect(headers['X-Cache']).to eq('BYPASS')
    expect(status).to eq(200)
    expect(body).to eq(['body'])
  end

  it 'uses default TTL if max-age is not present' do
    stub_response = build_stub_response(cache_control: '')
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(stub_response)
    expect(cache).to receive(:set).with(anything, anything, 1)
    server.call(rack_env)
  end
end
