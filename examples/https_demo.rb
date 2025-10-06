#!/usr/bin/env ruby
# frozen_string_literal: true
# encoding: utf-8

# HTTPS/SSL Support Demo for Caching Proxy
# This script demonstrates the HTTPS capabilities of the caching proxy

puts "[SSL] HTTPS/SSL Support Demo for Caching Proxy"
puts "=" * 50
puts

# Demo 1: Show SSL options
puts "1. Available SSL Options:"
puts "   --ssl                    Enable HTTPS/SSL support"
puts "   --ssl-port PORT          HTTPS port (default: 8443)"
puts "   --ssl-cert PATH          Path to SSL certificate"
puts "   --ssl-key PATH           Path to SSL private key"
puts

# Demo 2: Usage examples
puts "2. Usage Examples:"
puts
puts "   [Web] HTTPS only with auto-generated certificate:"
puts "   ruby bin/caching_proxy.rb --ssl --origin https://httpbin.org"
puts
puts "   [Dual] Both HTTP and HTTPS servers:"
puts "   ruby bin/caching_proxy.rb --port 8080 --ssl --ssl-port 8443 --origin https://httpbin.org"
puts
puts "   [Cert] Custom SSL certificate:"
puts "   ruby bin/caching_proxy.rb --ssl --ssl-cert my.crt --ssl-key my.key --origin https://api.example.com"
puts

# Demo 3: SSL Certificate features
puts "3. SSL Certificate Features:"
puts
puts "   + Automatic self-signed certificate generation"
puts "   + 2048-bit RSA encryption"
puts "   + Subject Alternative Names (SAN) support"
puts "   + Valid for localhost and 127.0.0.1"
puts "   + 1-year validity period"
puts "   + SHA-256 signature algorithm"
puts

# Demo 4: Testing commands
puts "4. Testing HTTPS Proxy:"
puts
puts "   Start the HTTPS proxy:"
puts "   ruby bin/caching_proxy.rb --ssl --ssl-port 8443 --origin https://httpbin.org"
puts
puts "   Test with curl (use -k to ignore self-signed cert warnings):"
puts "   curl -k -i https://localhost:8443/get"
puts "   curl -k -X POST -d 'test=data' https://localhost:8443/post"
puts

# Demo 5: Certificate management
puts "5. Certificate Management:"
puts
puts "   View certificate details:"
puts "   openssl x509 -in server.crt -text -noout"
puts
puts "   Verify certificate and key match:"
puts "   openssl x509 -noout -modulus -in server.crt | openssl md5"
puts "   openssl rsa -noout -modulus -in server.key | openssl md5"
puts
puts "   Trust certificate (macOS - for development only):"
puts "   sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain server.crt"
puts

# Demo 6: Security features
puts "6. Security Features:"
puts
puts "   [SEC] SSL/TLS encryption for client-proxy communication"
puts "   [SEC] Certificate verification and validation"
puts "   [SEC] Secure private key storage (600 permissions)"
puts "   [SEC] Modern cipher suites and protocols"
puts "   [SEC] Hop-by-hop header filtering for security"
puts

# Demo 7: Production considerations
puts "7. Production Considerations:"
puts
puts "   - Use proper CA-signed certificates in production"
puts "   - Consider using a reverse proxy (nginx/Apache) for SSL termination"
puts "   - Implement proper certificate rotation and management"
puts "   - Enable HSTS headers for enhanced security"
puts "   - Regular security audits and updates"
puts

puts "[Done] Ready to secure your caching proxy with HTTPS!"
puts "   Run with --ssl to get started!"
