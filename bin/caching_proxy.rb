#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require 'rack'
require 'webrick'
require 'rackup/handler/webrick'
require 'openssl'
require 'stringio'
require 'caching_proxy/cli'
require 'caching_proxy/server'
require 'caching_proxy/cache'
require 'caching_proxy/ssl_certificate_generator'

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

if (options[:port] || options[:ssl]) && options[:origin]
  begin
    app = CachingProxy::Server.new(options[:origin], cache)

    # Start HTTP server if port is specified
    if options[:port]
      puts "Starting HTTP server on port #{options[:port]}..."
      if options[:ssl]
        # Start HTTP server in background thread if we also have SSL
        Thread.new do
          Rackup::Handler::WEBrick.run app, Port: options[:port], Logger: WEBrick::Log.new('/dev/null')
        end
        sleep 1 # Give HTTP server time to start
      else
        # Start HTTP server as main process if no SSL
        Rackup::Handler::WEBrick.run app, Port: options[:port]
        exit
      end
    end

    # Start HTTPS server if SSL is enabled
    if options[:ssl]
      ssl_port = options[:ssl_port] || 8443
      ssl_cert = options[:ssl_cert] || 'server.crt'
      ssl_key = options[:ssl_key] || 'server.key'

      # Generate or verify SSL certificate
      unless CachingProxy::SSLCertificateGenerator.verify_certificate(ssl_cert, ssl_key)
        puts "SSL certificate not found or invalid. Generating self-signed certificate..."
        cert_info = CachingProxy::SSLCertificateGenerator.generate_self_signed(
          cert_file: ssl_cert,
          key_file: ssl_key
        )
        ssl_cert = cert_info[:cert]
        ssl_key = cert_info[:key]
      end

      puts "Starting HTTPS server on port #{ssl_port}..."
      puts "SSL Certificate: #{ssl_cert}"
      puts "SSL Key: #{ssl_key}"

      # Use Rackup handler with SSL options
      ssl_options = {
        Port: ssl_port,
        SSLEnable: true,
        SSLCertificate: OpenSSL::X509::Certificate.new(File.read(ssl_cert)),
        SSLPrivateKey: OpenSSL::PKey.read(File.read(ssl_key)),
        SSLVerifyClient: OpenSSL::SSL::VERIFY_NONE,
        Logger: WEBrick::Log.new(STDOUT, WEBrick::Log::INFO)
      }

      # Handle shutdown gracefully
      trap('INT') { exit }
      trap('TERM') { exit }

      Rackup::Handler::WEBrick.run(app, **ssl_options)
    end

  rescue => e
    puts "Caching server error: #{e.message}"
    puts e.backtrace.join("\n") if ENV['DEBUG']
  end
else
  puts "Missing --port or --ssl (with --origin)"
end
