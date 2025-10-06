# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'stringio'
require_relative '../lib/caching_proxy/ssl_certificate_generator'

RSpec.describe 'CachingProxy::SSLCertificateGenerator' do
  let(:temp_dir) { Dir.mktmpdir }
  let(:cert_file) { File.join(temp_dir, 'test.crt') }
  let(:key_file) { File.join(temp_dir, 'test.key') }

  # Safe output capturing helper
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe '.generate_self_signed' do
    it 'generates a valid self-signed certificate' do
      result = CachingProxy::SSLCertificateGenerator.generate_self_signed(
        hostname: 'test.example.com',
        output_dir: temp_dir,
        cert_file: 'test.crt',
        key_file: 'test.key',
        validity_days: 30
      )

      expect(result[:cert]).to eq(cert_file)
      expect(result[:key]).to eq(key_file)
      expect(File.exist?(cert_file)).to be true
      expect(File.exist?(key_file)).to be true

      # Verify certificate content
      cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
      expect(cert.subject.to_s).to include('CN=test.example.com')
      expect(cert.not_after).to be > Time.now
      expect(cert.not_before).to be <= Time.now

      # Verify key content
      key = OpenSSL::PKey.read(File.read(key_file))
      expect(key).to be_a(OpenSSL::PKey::RSA)
      expect(key.n.num_bits).to eq(2048)
    end

    it 'sets correct permissions on private key' do
      CachingProxy::SSLCertificateGenerator.generate_self_signed(
        output_dir: temp_dir,
        cert_file: 'test.crt',
        key_file: 'test.key'
      )

      key_stat = File.stat(key_file)
      expect(key_stat.mode & 0o777).to eq(0o600)
    end

    it 'includes Subject Alternative Names' do
      CachingProxy::SSLCertificateGenerator.generate_self_signed(
        hostname: 'myhost.local',
        output_dir: temp_dir,
        cert_file: 'test.crt',
        key_file: 'test.key'
      )

      cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
      san_extension = cert.extensions.find { |ext| ext.oid == 'subjectAltName' }

      expect(san_extension).not_to be_nil
      expect(san_extension.value).to include('DNS:myhost.local')
      expect(san_extension.value).to include('DNS:localhost')
      expect(san_extension.value).to include('IP Address:127.0.0.1')
    end
  end

  describe '.verify_certificate' do
    before do
      CachingProxy::SSLCertificateGenerator.generate_self_signed(
        output_dir: temp_dir,
        cert_file: 'test.crt',
        key_file: 'test.key'
      )
    end

    it 'returns true for valid certificate and key pair' do
      expect(CachingProxy::SSLCertificateGenerator.verify_certificate(cert_file, key_file)).to be true
    end

    it 'returns false when files do not exist' do
      expect(CachingProxy::SSLCertificateGenerator.verify_certificate('nonexistent.crt', 'nonexistent.key')).to be false
    end

    it 'returns false when certificate and key do not match' do
      # Generate another key pair
      other_key_file = File.join(temp_dir, 'other.key')
      other_key = OpenSSL::PKey::RSA.new(2048)
      File.write(other_key_file, other_key.to_pem)

      expect(CachingProxy::SSLCertificateGenerator.verify_certificate(cert_file, other_key_file)).to be false
    end

    it 'returns false for expired certificate' do
      # Create an expired certificate
      expired_cert_file = File.join(temp_dir, 'expired.crt')
      rsa_key = OpenSSL::PKey::RSA.new(2048)

      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = OpenSSL::X509::Name.parse("/CN=localhost")
      cert.issuer = cert.subject
      cert.public_key = rsa_key.public_key
      cert.not_before = Time.now - (2 * 24 * 60 * 60) # 2 days ago
      cert.not_after = Time.now - (1 * 24 * 60 * 60)  # 1 day ago (expired)
      cert.sign(rsa_key, OpenSSL::Digest::SHA256.new)

      File.write(expired_cert_file, cert.to_pem)
      expired_key_file = File.join(temp_dir, 'expired.key')
      File.write(expired_key_file, rsa_key.to_pem)

      expect(CachingProxy::SSLCertificateGenerator.verify_certificate(expired_cert_file, expired_key_file)).to be false
    end
  end

  describe '.certificate_info' do
    before do
      CachingProxy::SSLCertificateGenerator.generate_self_signed(
        hostname: 'info.test.com',
        output_dir: temp_dir,
        cert_file: 'test.crt',
        key_file: 'test.key'
      )
    end

    it 'displays certificate information' do
      output = capture_stdout do
        CachingProxy::SSLCertificateGenerator.certificate_info(cert_file)
      end

      expect(output).to include('SSL Certificate Information:')
      expect(output).to include('Subject:')
      expect(output).to include('CN=info.test.com')
      expect(output).to include('Subject Alt Names:')
      expect(output).to include('DNS:info.test.com')
      expect(output).to include('Status: VALID')
      expect(output).to include('Key Algorithm: RSA (2048 bits)')
    end

    it 'handles non-existent certificate file gracefully' do
      output = capture_stdout do
        CachingProxy::SSLCertificateGenerator.certificate_info('nonexistent.crt')
      end
      
      expect(output).to include("Error: Certificate file 'nonexistent.crt' does not exist")
    end

    it 'handles invalid certificate file content gracefully' do
      invalid_cert_file = File.join(temp_dir, 'invalid.crt')
      File.write(invalid_cert_file, 'This is not a valid certificate')

      output = capture_stdout do
        CachingProxy::SSLCertificateGenerator.certificate_info(invalid_cert_file)
      end

      expect(output).to include("Error: Invalid certificate file")
      expect(output).to include("corrupted or not in PEM/DER format")
    end

    it 'handles empty certificate file gracefully' do
      empty_cert_file = File.join(temp_dir, 'empty.crt')
      File.write(empty_cert_file, '')

      output = capture_stdout do
        CachingProxy::SSLCertificateGenerator.certificate_info(empty_cert_file)
      end

      expect(output).to include("Error: Invalid certificate file")
    end
  end

  describe '.verify_certificate error handling' do
    it 'handles invalid certificate file content gracefully' do
      # Create valid key but invalid certificate
      CachingProxy::SSLCertificateGenerator.generate_self_signed(
        output_dir: temp_dir,
        cert_file: 'test.crt',
        key_file: 'test.key'
      )
      
      invalid_cert_file = File.join(temp_dir, 'invalid.crt')
      File.write(invalid_cert_file, 'This is not a valid certificate')

      output = capture_stdout do
        result = CachingProxy::SSLCertificateGenerator.verify_certificate(invalid_cert_file, key_file)
        expect(result).to be false
      end

      expect(output).to include("Error: Invalid certificate file")
    end

    it 'handles invalid private key file content gracefully' do
      # Create valid certificate but invalid key
      CachingProxy::SSLCertificateGenerator.generate_self_signed(
        output_dir: temp_dir,
        cert_file: 'test.crt',
        key_file: 'test.key'
      )
      
      invalid_key_file = File.join(temp_dir, 'invalid.key')
      File.write(invalid_key_file, 'This is not a valid private key')

      output = capture_stdout do
        result = CachingProxy::SSLCertificateGenerator.verify_certificate(cert_file, invalid_key_file)
        expect(result).to be false
      end

      expect(output).to include("Error: Invalid private key file")
    end

    it 'handles empty certificate file gracefully' do
      # Create valid key but empty certificate
      CachingProxy::SSLCertificateGenerator.generate_self_signed(
        output_dir: temp_dir,
        cert_file: 'test.crt',
        key_file: 'test.key'
      )
      
      empty_cert_file = File.join(temp_dir, 'empty.crt')
      File.write(empty_cert_file, '')

      output = capture_stdout do
        result = CachingProxy::SSLCertificateGenerator.verify_certificate(empty_cert_file, key_file)
        expect(result).to be false
      end

      expect(output).to include("Error: Invalid certificate file")
    end

    it 'handles empty private key file gracefully' do
      # Create valid certificate but empty key
      CachingProxy::SSLCertificateGenerator.generate_self_signed(
        output_dir: temp_dir,
        cert_file: 'test.crt',
        key_file: 'test.key'
      )
      
      empty_key_file = File.join(temp_dir, 'empty.key')
      File.write(empty_key_file, '')

      output = capture_stdout do
        result = CachingProxy::SSLCertificateGenerator.verify_certificate(cert_file, empty_key_file)
        expect(result).to be false
      end

      expect(output).to include("Error: Invalid private key file")
    end
  end
end
