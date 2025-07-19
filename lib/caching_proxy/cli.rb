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
      end.parse!
      options
    end
  end
end
