#!/usr/bin/env ruby
# frozen_string_literal: true
# encoding: utf-8

# Demo script showing hop-by-hop header filtering
# Run this to see which headers get filtered out

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'caching_proxy/server'
require 'caching_proxy/cache'
require 'json'

puts "=== Caching Proxy Hop-by-Hop Header Filtering Demo ==="
puts

# Show the hop-by-hop headers that get filtered
puts "Headers filtered out by the proxy (RFC 2616/7230 compliance):"
CachingProxy::Server::HOP_BY_HOP_HEADERS.each do |header|
  puts "  - #{header}"
end
puts

# Demonstrate the filtering logic
puts "Testing header filtering logic:"
test_headers = [
  'Content-Type',      # Should pass through
  'Authorization',     # Should pass through  
  'Connection',        # Should be filtered
  'Transfer-Encoding', # Should be filtered
  'User-Agent',        # Should pass through
  'Upgrade',           # Should be filtered
  'Keep-Alive',        # Should be filtered
  'X-Custom-Header'    # Should pass through
]

cache = CachingProxy::Cache.new(300)
server = CachingProxy::Server.new('http://example.com', cache)

test_headers.each do |header|
  filtered = server.send(:hop_by_hop_header?, header)
  status = filtered ? "[FILTERED]" : "[FORWARDED]"
  puts "  #{header.ljust(20)} #{status}"
end

puts
puts "The proxy ensures clean HTTP communication by:"
puts "* Removing connection-specific headers from requests"
puts "* Filtering hop-by-hop headers from responses"  
puts "* Maintaining RFC compliance for proper proxy behavior"
puts "* Preventing header pollution between client-proxy-origin"