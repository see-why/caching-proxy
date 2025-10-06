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

        opts.on("--ssl", "Enable HTTPS/SSL support") do
          options[:ssl] = true
        end

        opts.on("--ssl-cert PATH", String, "Path to SSL certificate file (.crt or .pem)") do |v|
          options[:ssl_cert] = v
        end

        opts.on("--ssl-key PATH", String, "Path to SSL private key file (.key or .pem)") do |v|
          options[:ssl_key] = v
        end

        opts.on("--ssl-port PORT", Integer, "HTTPS port (default: 8443)") do |v|
          options[:ssl_port] = v
        end
      end.parse!
      options
    end
  end
end
