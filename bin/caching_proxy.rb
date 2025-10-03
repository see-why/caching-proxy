#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require 'rack'
require 'webrick'
require 'rackup/handler/webrick'
require 'caching_proxy/cli'
require 'caching_proxy/server'
require 'caching_proxy/cache'

options = CachingProxy::Cli.parse_args
cache = CachingProxy::Cache.new

if options[:clear_cache]
  cache.clear
  puts "Cache cleared"
  exit
end

if options[:invalidate_key]
  result = cache.invalidate(options[:invalidate_key])
  if result
    puts "Key '#{options[:invalidate_key]}' invalidated"
  else
    puts "Key '#{options[:invalidate_key]}' not found"
  end
  exit
end

if options[:invalidate_pattern]
  deleted_keys = cache.invalidate_pattern(options[:invalidate_pattern])
  puts "#{deleted_keys.size} keys invalidated matching pattern '#{options[:invalidate_pattern]}'"
  deleted_keys.each { |key| puts "  - #{key}" }
  exit
end

if options[:cache_stats]
  stats = cache.stats
  puts "Cache Statistics:"
  puts "  Total keys: #{stats[:total_keys]}"
  puts "  Active keys: #{stats[:active_keys]}"
  puts "  Expired keys: #{stats[:expired_keys]}"
  exit
end

if options[:cache_keys]
  keys = cache.keys
  puts "Cache Keys (#{keys.size}):"
  keys.each { |key| puts "  - #{key}" }
  exit
end

if options[:port] && options[:origin]
  begin
    app = CachingProxy::Server.new(options[:origin], cache)
    Rackup::Handler::WEBrick.run app, Port: options[:port]
  rescue => e
    puts "Caching server error: #{e}"
  end
else
  puts "Missing --port or --origin"
end
