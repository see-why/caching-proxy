# Caching Proxy

A high-performance HTTP/HTTPS caching proxy server built in Ruby with support for multiple persistent cache backends.

## Features

- **HTTP/HTTPS Proxy**: Complete proxy functionality with SSL/TLS support
- **Multi-Backend Caching**: Memory, Redis, and SQLite cache backends with automatic failover
- **Persistent Storage**: Cache survives server restarts with Redis and SQLite backends
- **Smart Invalidation**: Pattern-based cache clearing with wildcard support
- **SSL Certificate Management**: Automatic self-signed certificate generation or custom certificates
- **Cache Statistics**: Comprehensive monitoring and performance metrics
- **Production Ready**: Error handling, connection pooling, and graceful degradation

## Quick Start

```bash
# Clone and install
git clone https://github.com/see-why/caching-proxy.git
cd caching-proxy
bundle install

# Basic usage
ruby bin/caching_proxy.rb --port 8080 --origin https://httpbin.org

# With persistent cache
ruby bin/caching_proxy.rb --port 8080 --origin https://api.example.com --cache-backend sqlite
```

## Installation

### Prerequisites
- Ruby 3.0 or higher
- Bundler

### Setup
```bash
bundle install
```

For persistent backends:
- **Redis**: Optional, for distributed caching
- **SQLite3**: Included with Ruby, for local persistence

## Usage

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-p, --port PORT` | Server port | 3000 |
| `-o, --origin URL` | Origin server URL | Required |
| `--cache-backend BACKEND` | Cache type (memory/redis/sqlite) | memory |
| `--cache-ttl TTL` | Cache TTL in seconds | 3600 |
| `--cache-db PATH` | SQLite database file | cache.db |
| `--cache-redis-host HOST` | Redis host | localhost |
| `--cache-redis-port PORT` | Redis port | 6379 |
| `--cert FILE` | SSL certificate file | - |
| `--key FILE` | SSL private key file | - |
| `--skip-ssl-verify` | Skip upstream SSL verification | false |
| `--clear-cache` | Clear cache on startup | false |
| `--cache-info` | Show cache backend info | - |

### Cache Backends

#### Memory Cache (Default)
```bash
ruby bin/caching_proxy.rb --port 8080 --origin https://api.example.com
```
- ✅ Ultra-fast access
- ❌ No persistence

#### SQLite Cache (Single Server)
```bash
ruby bin/caching_proxy.rb --port 8080 --origin https://api.example.com \
  --cache-backend sqlite --cache-db production.db
```
- ✅ Local persistence
- ✅ Zero configuration
- ❌ Single node only

#### Redis Cache (Production)
```bash
ruby bin/caching_proxy.rb --port 8080 --origin https://api.example.com \
  --cache-backend redis --cache-redis-host redis.example.com
```
- ✅ Distributed caching
- ✅ High performance
- ✅ Clustering support
- ❌ Requires Redis server

### HTTPS/SSL Support

```bash
# Auto-generated self-signed certificate
ruby bin/caching_proxy.rb --port 8443 --origin https://api.example.com \
  --cert server.crt --key server.key

# Skip SSL verification for development
ruby bin/caching_proxy.rb --origin https://self-signed.example.com --skip-ssl-verify
```

## Testing

```bash
# First request (cache miss)
curl -v http://localhost:8080/api/users
# X-Cache: MISS

# Second request (cache hit)  
curl -v http://localhost:8080/api/users
# X-Cache: HIT

# Check available backends
ruby bin/caching_proxy.rb --cache-info
```

## Architecture

```text
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│     Client      │───▶│  Caching Proxy   │───▶│  Origin Server  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Cache Backend   │
                    │ ┌──────────────┐ │
                    │ │    Memory    │ │
                    │ │    Redis     │ │
                    │ │   SQLite     │ │
                    │ └──────────────┘ │
                    └──────────────────┘
```

### Core Components
- **CLI** (`lib/caching_proxy/cli.rb`): Command-line interface
- **Server** (`lib/caching_proxy/server.rb`): HTTP/HTTPS request handling  
- **Cache Factory** (`lib/caching_proxy/cache_factory.rb`): Backend selection with failover

### Cache Strategy
- **Caching**: GET, HEAD, OPTIONS requests
- **Invalidation**: POST, PUT, DELETE, PATCH trigger cache clearing
- **TTL**: Configurable expiration times
- **Patterns**: Wildcard invalidation (`/api/users/*`)

## Performance

| Backend | Speed | Persistence | Distribution | Setup |
|---------|-------|-------------|--------------|-------|
| Memory  | ⚡⚡⚡ | ❌ | Single | None |
| SQLite  | ⚡⚡ | ✅ | Single | Minimal |
| Redis   | ⚡⚡ | ✅ | Multi | Redis Server |

## Development

### Running Tests
```bash
bundle exec rspec
bundle exec rspec spec/persistent_cache_spec.rb
```

### Contributing
1. Fork the repository
2. Create feature branch (`git checkout -b feature/new-feature`)
3. Add tests and implement changes
4. Submit pull request

## Troubleshooting

### Redis Connection Issues
```bash
# Check Redis server
redis-cli ping

# Start Redis
redis-server

# Test connection
ruby bin/caching_proxy.rb --cache-backend redis --cache-info
```

### SSL Certificate Issues
```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes

# Test HTTPS
curl -k https://localhost:8443/api/test
```

### SQLite Permission Issues
```bash
# Ensure directory is writable
chmod 755 /path/to/cache/directory

# Use absolute path
ruby bin/caching_proxy.rb --cache-db /full/path/to/cache.db
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Links

- **Repository**: https://github.com/see-why/caching-proxy
- **Issues**: https://github.com/see-why/caching-proxy/issues
- **Project Specification**: https://roadmap.sh/projects/caching-server
