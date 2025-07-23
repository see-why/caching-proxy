# frozen_string_literal: true

require_relative '../lib/caching_proxy/cache'

RSpec.describe 'Cache' do
  subject { CachingProxy::Cache.new }

  let(:url) { 'url@get.com' }
  let(:response) { { status: 200, data: :success } }

  it 'sets a value with a key' do
    subject.set(url, response)

    expect(subject.get(url)).to eq(response)
  end
end
