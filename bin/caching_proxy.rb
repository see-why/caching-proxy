#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require 'rack'
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

if options[:port] && options[:origin]
  begin
    app = CachingProxy::Server.new(options[:origin], cache)
    Rack::Handler::WEBrick.run app, Port: options[:port]
  rescue => e
    puts "Cached server error: #{e}"
  end
else
  puts "Missing --port or --origin"
end
