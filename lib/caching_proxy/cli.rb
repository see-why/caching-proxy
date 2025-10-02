# frozen_string_literal: true

require 'optparse'

module CachingProxy
  class Cli
    def self.parse_args
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: caching-proxy [options]"

        opts.on("--port PORT", Integer, "Port to run the proxy") do |v|
          options[:port] = v
        end

        opts.on("--origin URL", String, "Origin server URL") do |v|
          options[:origin] = v
        end

        opts.on("--clear-cache", "Clear the cache") do
          options[:clear_cache] = true
        end

        opts.on("--invalidate-key KEY", String, "Invalidate a specific cache key") do |v|
          options[:invalidate_key] = v
        end

        opts.on("--invalidate-pattern PATTERN", String, "Invalidate cache keys matching pattern (supports * and ?)") do |v|
          options[:invalidate_pattern] = v
        end

        opts.on("--cache-stats", "Show cache statistics") do
          options[:cache_stats] = true
        end

        opts.on("--cache-keys", "List all cache keys") do
          options[:cache_keys] = true
        end
      end.parse!
      options
    end
  end
end
