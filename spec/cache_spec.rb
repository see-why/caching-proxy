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
end
