# Caching Proxy

A lightweight HTTP caching proxy server built in Ruby that sits between clients and origin servers to cache responses and improve performance.

## Features

- **HTTP Proxy**: Forward requests to origin servers
- **Response Caching**: Cache successful responses to reduce load on origin servers
- **Cache Management**: Intelligent cache invalidation and storage
- **Command Line Interface**: Easy-to-use CLI for configuration and management
- **Lightweight**: Built with minimal dependencies using Rack and WEBrick

## Installation

### Prerequisites

- Ruby 2.7 or higher
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

- `--port, -p`: Port to run the proxy server on (default: 3000)
- `--origin, -o`: Origin server URL to proxy requests to
- `--cache-dir`: Directory to store cached responses (default: ./cache)
- `--help, -h`: Show help message

### Examples

1. **Basic proxy with caching**:

```bash
ruby bin/caching_proxy.rb --port 3000 --origin https://jsonplaceholder.typicode.com
```

2. **Custom cache directory**:

```bash
ruby bin/caching_proxy.rb --port 8080 --origin https://api.example.com --cache-dir /tmp/proxy-cache
```

3. **Test the proxy**:

```bash
# First request (cache miss)
curl -i http://localhost:3000/posts/1

# Second request (cache hit)
curl -i http://localhost:3000/posts/1
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

- **Storage**: File-based caching system
- **Key Generation**: Based on request URL and method
- **Invalidation**: Time-based expiration (configurable)
- **Headers**: Respects cache-control headers from origin servers

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

---

For more information, issues, or contributions, please visit the [GitHub repository](https://github.com/see-why/caching-proxy).