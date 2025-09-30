# frozen_string_literal: true

require_relative '../lib/caching_proxy/cache'

RSpec.describe 'Cache Invalidation' do
  subject { CachingProxy::Cache.new(300) }

  before do
    subject.set('user:1', { name: 'Alice' })
    subject.set('user:2', { name: 'Bob' })
    subject.set('post:1', { title: 'Hello' })
    subject.set('post:2', { title: 'World' })
    subject.set('session:abc123', { user_id: 1 })
  end

  describe '#invalidate_pattern' do
    it 'invalidates keys matching wildcard pattern' do
      deleted_keys = subject.invalidate_pattern('user:*')
      expect(deleted_keys).to include('user:1', 'user:2')
      expect(deleted_keys.size).to eq(2)
      expect(subject.get('user:1')).to be_nil
      expect(subject.get('user:2')).to be_nil
      expect(subject.get('post:1')).not_to be_nil
    end

    it 'invalidates keys matching single character pattern' do
      deleted_keys = subject.invalidate_pattern('user:?')
      expect(deleted_keys).to include('user:1', 'user:2')
      expect(deleted_keys.size).to eq(2)
    end

    it 'invalidates exact key match' do
      deleted_keys = subject.invalidate_pattern('post:1')
      expect(deleted_keys).to eq(['post:1'])
      expect(subject.get('post:1')).to be_nil
      expect(subject.get('post:2')).not_to be_nil
    end

    it 'returns empty array when no keys match' do
      deleted_keys = subject.invalidate_pattern('nonexistent:*')
      expect(deleted_keys).to eq([])
    end

    it 'handles complex patterns' do
      deleted_keys = subject.invalidate_pattern('*:*')
      expect(deleted_keys.size).to eq(5) # All keys match
    end
  end

  describe '#keys' do
    it 'returns all non-expired keys' do
      keys = subject.keys
      expect(keys).to include('user:1', 'user:2', 'post:1', 'post:2', 'session:abc123')
      expect(keys.size).to eq(5)
    end
  end

  describe '#stats' do
    it 'returns cache statistics' do
      stats = subject.stats
      expect(stats[:total_keys]).to eq(5)
      expect(stats[:active_keys]).to eq(5)
      expect(stats[:expired_keys]).to eq(0)
    end
  end

  describe '#size' do
    it 'returns total number of stored entries' do
      expect(subject.size).to eq(5)
    end
  end
end
