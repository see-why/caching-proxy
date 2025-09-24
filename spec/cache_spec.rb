# frozen_string_literal: true

require_relative '../lib/caching_proxy/cache'

RSpec.describe 'Cache' do
  subject { CachingProxy::Cache.new }

  let(:url) { 'url@get.com' }
  let(:response) { { status: 200, data: :success } }

  before do
    subject.set(url, response)
  end

  it 'sets a value with a key' do
    expect(subject.get(url)).to eq(response)
  end

  it 'clears its store' do
    subject.clear

    expect(subject.get(url)).to be_nil
  end

  it 'returns true for key? when key exists' do
    expect(subject.key?(url)).to be true
  end

  it 'returns false for key? when key does not exist' do
    expect(subject.key?('missing')).to be false
  end

  it 'overwrites a value for the same key' do
    new_response = { status: 404, data: :fail }
    subject.set(url, new_response)
    expect(subject.get(url)).to eq(new_response)
  end

  it 'stores and retrieves multiple keys' do
    url2 = 'another@site.com'
    response2 = { status: 201, data: :created }
    subject.set(url2, response2)
    expect(subject.get(url)).to eq(response)
    expect(subject.get(url2)).to eq(response2)
  end

  it 'handles nil key and nil value' do
    subject.set(nil, nil)
    expect(subject.get(nil)).to be_nil
    expect(subject.key?(nil)).to be true
  end

  it 'clear works on empty cache' do
    subject.clear
    expect(subject.get('anything')).to be_nil
    expect(subject.key?('anything')).to be false
  end
end
