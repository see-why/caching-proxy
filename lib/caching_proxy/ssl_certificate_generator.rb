# frozen_string_literal: true

require 'openssl'
require 'fileutils'

module CachingProxy
  class SSLCertificateGenerator
    def self.generate_self_signed(
      hostname: 'localhost',
      output_dir: '.',
      cert_file: 'server.crt',
      key_file: 'server.key',
      validity_days: 365
    )
      puts "Generating self-signed SSL certificate for #{hostname}..."

      # Generate RSA key pair
      rsa_key = OpenSSL::PKey::RSA.new(2048)

      # Create certificate
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = Random.rand(1..65535)
      cert.subject = OpenSSL::X509::Name.parse("/CN=#{hostname}")
      cert.issuer = cert.subject
      cert.public_key = rsa_key.public_key
      cert.not_before = Time.now
      cert.not_after = Time.now + (validity_days * 24 * 60 * 60)

      # Add extensions for modern browsers
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = cert

      cert.add_extension(ef.create_extension("basicConstraints", "CA:TRUE", true))
      cert.add_extension(ef.create_extension("keyUsage", "keyCertSign, cRLSign", true))
      cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash", false))
      cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid:always", false))

      # Add Subject Alternative Name for localhost and 127.0.0.1
      san_list = ["DNS:#{hostname}"]
      san_list << "DNS:localhost" unless hostname == 'localhost'
      san_list << "IP:127.0.0.1"
      cert.add_extension(ef.create_extension("subjectAltName", san_list.join(','), false))

      # Self-sign the certificate
      cert.sign(rsa_key, OpenSSL::Digest::SHA256.new)

      # Ensure output directory exists
      FileUtils.mkdir_p(output_dir)

      # Write certificate and key to files
      cert_path = File.join(output_dir, cert_file)
      key_path = File.join(output_dir, key_file)

      File.write(cert_path, cert.to_pem)
      File.write(key_path, rsa_key.to_pem)

      # Set appropriate permissions on private key
      File.chmod(0600, key_path)

      puts "Generated SSL certificate:"
      puts "  Certificate: #{cert_path}"
      puts "  Private Key: #{key_path}"
      puts "  Valid until: #{cert.not_after}"
      puts
      puts "To trust this certificate (macOS):"
      puts "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain #{cert_path}"
      puts
      puts "To trust this certificate (Linux):"
      puts "  sudo cp #{cert_path} /usr/local/share/ca-certificates/caching-proxy.crt"
      puts "  sudo update-ca-certificates"

      { cert: cert_path, key: key_path }
    end

    def self.verify_certificate(cert_file, key_file)
      return false unless File.exist?(cert_file) && File.exist?(key_file)

      begin
        # Read and parse certificate file
        cert_data = File.read(cert_file)
        cert = OpenSSL::X509::Certificate.new(cert_data)
      rescue OpenSSL::X509::CertificateError => e
        puts "Error: Invalid certificate file '#{cert_file}': #{e.message}"
        return false
      rescue Errno::EACCES => e
        puts "Error: Cannot read certificate file '#{cert_file}': #{e.message}"
        return false
      rescue => e
        puts "Error: Failed to read certificate file '#{cert_file}': #{e.message}"
        return false
      end

      begin
        # Read and parse private key file
        key_data = File.read(key_file)
        key = OpenSSL::PKey.read(key_data)
      rescue OpenSSL::PKey::PKeyError => e
        puts "Error: Invalid private key file '#{key_file}': #{e.message}"
        return false
      rescue Errno::EACCES => e
        puts "Error: Cannot read private key file '#{key_file}': #{e.message}"
        return false
      rescue => e
        puts "Error: Failed to read private key file '#{key_file}': #{e.message}"
        return false
      end

      begin
        # Verify certificate and key match
        unless cert.public_key.to_pem == key.public_key.to_pem
          puts "Error: SSL certificate and private key don't match"
          return false
        end

        # Check if certificate has expired
        if cert.not_after < Time.now
          puts "Warning: SSL certificate has expired (#{cert.not_after})"
          return false
        end

        # Check if certificate is valid for localhost
        san_extension = cert.extensions.find { |ext| ext.oid == 'subjectAltName' }
        if san_extension && !san_extension.value.include?('localhost')
          puts "Warning: SSL certificate may not be valid for localhost"
        end

        true
      rescue OpenSSL::OpenSSLError => e
        puts "Error: SSL certificate verification failed: #{e.message}"
        false
      rescue => e
        puts "Error: Unexpected error during certificate verification: #{e.message}"
        false
      end
    end

    def self.certificate_info(cert_file)
      unless File.exist?(cert_file)
        puts "Error: Certificate file '#{cert_file}' does not exist"
        return
      end

      begin
        cert_data = File.read(cert_file)
        cert = OpenSSL::X509::Certificate.new(cert_data)

        puts "SSL Certificate Information:"
        puts "  Subject: #{cert.subject}"
        puts "  Issuer: #{cert.issuer}"
        puts "  Valid from: #{cert.not_before}"
        puts "  Valid until: #{cert.not_after}"
        puts "  Serial: #{cert.serial}"

        # Check expiration status
        if cert.not_after < Time.now
          puts "  Status: EXPIRED (#{cert.not_after})"
        elsif cert.not_before > Time.now
          puts "  Status: NOT YET VALID (starts #{cert.not_before})"
        else
          puts "  Status: VALID"
        end

        # Display Subject Alternative Names if present
        san_extension = cert.extensions.find { |ext| ext.oid == 'subjectAltName' }
        if san_extension
          puts "  Subject Alt Names: #{san_extension.value}"
        end

        # Display key algorithm and size
        public_key = cert.public_key
        if public_key.respond_to?(:n) # RSA key
          puts "  Key Algorithm: RSA (#{public_key.n.num_bits} bits)"
        else
          puts "  Key Algorithm: #{public_key.class}"
        end

      rescue OpenSSL::X509::CertificateError => e
        puts "Error: Invalid certificate file '#{cert_file}': #{e.message}"
        puts "The file may be corrupted or not in PEM/DER format"
      rescue Errno::EACCES => e
        puts "Error: Cannot read certificate file '#{cert_file}': #{e.message}"
        puts "Check file permissions"
      rescue => e
        puts "Error: Failed to read certificate information from '#{cert_file}': #{e.message}"
      end
    end
  end
end
