# Caching Proxy

A lightweight HTTP caching proxy server built in Ruby that sits between clients and origin servers to cache responses and improve performance.

## Features

- **HTTP Proxy**: Forward all HTTP methods (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS) to origin servers
- **Response Caching**: Cache successful responses to reduce load on origin servers
- **Smart Cache Invalidation**: Automatically invalidate cache on data-modifying operations
- **Cache Management**: Manual cache invalidation and storage with pattern matching
- **HTTP Cache-Control**: Respects standard HTTP caching headers (max-age, no-cache, no-store)
- **Command Line Interface**: Easy-to-use CLI for configuration and management
- **Admin API**: RESTful endpoints for cache management
- **Lightweight**: Built with minimal dependencies using Rack and WEBrick

## Installation

### Prerequisites

- Ruby 3.0 or higher
- Bundler

### Setup

1. Clone the repository:

```bash
git clone https://github.com/see-why/caching-proxy.git
cd caching-proxy
```

2. Install dependencies:

```bash
bundle install
```

## Usage

### Basic Usage

Start the caching proxy server:

```bash
ruby bin/caching_proxy.rb --port 3000 --origin http://example.com
```

### Command Line Options

**Server Options:**
- `--port PORT`: Port to run the proxy server on
- `--origin URL`: Origin server URL to proxy requests to

**Cache Management Options:**
- `--clear-cache`: Clear all cached entries
- `--invalidate-key KEY`: Invalidate a specific cache key
- `--invalidate-pattern PATTERN`: Invalidate keys matching pattern (supports * and ?)
- `--cache-stats`: Show cache statistics
- `--cache-keys`: List all cache keys

### Examples

1. **Basic proxy with caching**:

```bash
ruby bin/caching_proxy.rb --port 3000 --origin https://jsonplaceholder.typicode.com
```

2. **Custom cache directory**:

```bash
ruby bin/caching_proxy.rb --port 8080 --origin https://api.example.com --cache-dir /tmp/proxy-cache
```

3. **Test the proxy with different HTTP methods**:

```bash
# GET request (cached)
curl -i http://localhost:3000/posts/1

# Second GET request (cache hit)
curl -i http://localhost:3000/posts/1

# POST request (not cached, may invalidate related cache)
curl -X POST -H "Content-Type: application/json" \
  -d '{"title": "New Post"}' \
  http://localhost:3000/posts

# PUT request (not cached, invalidates related cache)
curl -X PUT -H "Content-Type: application/json" \
  -d '{"title": "Updated Post"}' \
  http://localhost:3000/posts/1

# DELETE request (not cached, invalidates related cache)
curl -X DELETE http://localhost:3000/posts/1
```

### Cache Management

1. **Clear all cache**:
```bash
ruby bin/caching_proxy.rb --clear-cache
```

2. **Invalidate specific key**:
```bash
ruby bin/caching_proxy.rb --invalidate-key "https://api.example.com/posts/1"
```

3. **Invalidate keys by pattern**:
```bash
# Invalidate all user-related endpoints
ruby bin/caching_proxy.rb --invalidate-pattern "*users*"

# Invalidate specific post patterns
ruby bin/caching_proxy.rb --invalidate-pattern "*/posts/?"
```

4. **View cache statistics**:
```bash
ruby bin/caching_proxy.rb --cache-stats
```

5. **List all cache keys**:
```bash
ruby bin/caching_proxy.rb --cache-keys
```

### Admin Endpoints

When the proxy server is running, you can also manage the cache via HTTP endpoints:

```bash
# Get cache statistics
curl http://localhost:3000/__cache__/stats

# List all cache keys
curl http://localhost:3000/__cache__/keys

# Clear all cache
curl -X POST http://localhost:3000/__cache__/clear

# Invalidate specific key
curl -X POST "http://localhost:3000/__cache__/invalidate?key=https://api.example.com/posts/1"

# Invalidate by pattern
curl -X POST "http://localhost:3000/__cache__/invalidate?pattern=*users*"
```

## How It Works

1. **Request Interception**: The proxy receives HTTP requests from clients
2. **Cache Check**: Checks if a cached response exists for the request
3. **Cache Hit**: If cached, returns the stored response immediately
4. **Cache Miss**: If not cached, forwards the request to the origin server
5. **Response Caching**: Stores successful responses in the cache for future requests
6. **Response Delivery**: Returns the response to the client

## Architecture

```text
├── bin/
│   └── caching_proxy.rb    # Main executable script
├── lib/
│   └── caching_proxy/
│       ├── cli.rb          # Command line interface
│       ├── server.rb       # HTTP server implementation
│       └── cache.rb        # Cache management logic
├── Gemfile                 # Ruby dependencies
└── README.md              # This file
```

## Cache Strategy

- **Storage**: In-memory caching system with TTL support
- **Key Generation**: Based on HTTP method and request URL (`METHOD:URL`)
- **Method-Specific Caching**:
  - **GET, HEAD, OPTIONS**: Cached by default
  - **POST, PUT, DELETE, PATCH**: Not cached, but trigger cache invalidation
- **Smart Invalidation**: 
  - POST to `/users` invalidates `GET:/users/*`
  - PUT/DELETE to `/users/1` invalidates `GET:/users/1` and `GET:/users/*`
- **TTL**: Time-based expiration (configurable, respects max-age)
- **Headers**: Respects HTTP cache-control headers (max-age, no-cache, no-store)

## Development

### Running Tests

```bash
# Run the test suite
bundle exec rspec
```

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for your changes
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Configuration

The caching proxy can be configured through command line arguments or environment variables:

| Option | Environment Variable | Default | Description |
|--------|---------------------|---------|-------------|
| `--port` | `PROXY_PORT` | 3000 | Port to run the server on |
| `--origin` | `ORIGIN_URL` | - | Origin server URL (required) |
| `--cache-dir` | `CACHE_DIR` | ./cache | Cache storage directory |

## Performance

- **Cache Hit Ratio**: Monitor cache effectiveness
- **Response Times**: Significantly reduced for cached responses
- **Memory Usage**: Efficient file-based storage
- **Concurrent Requests**: Handles multiple simultaneous connections

## Troubleshooting

### Common Issues

1. **Port already in use**:
   - Change the port using `--port` option
   - Check if another service is running on the same port

2. **Origin server unreachable**:
   - Verify the origin URL is correct and accessible
   - Check network connectivity

3. **Cache directory permissions**:
   - Ensure the cache directory is writable
   - Check file system permissions

### Logs

The proxy logs important events including:

- Cache hits and misses
- Request forwarding
- Error conditions
- Server start/stop events

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Osita Cyril Iyadi

## Acknowledgments

- Built with Ruby's Rack framework
- Uses WEBrick for HTTP server functionality
- Inspired by modern caching proxy solutions
- [Project URL](https://roadmap.sh/projects/caching-server)

---

For more information, issues, or contributions, please visit the [GitHub repository](https://github.com/see-why/caching-proxy).
