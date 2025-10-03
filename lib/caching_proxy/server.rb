# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module CachingProxy
  class Server
    # Default pattern matches common ID formats:
    # - UUIDs: 123e4567-e89b-12d3-a456-426614174000
    # - Alphanumeric with numbers: abc123, user_123, item-456
    # - Numeric: 123, 456
    # - Must contain either a number, underscore, or hyphen to distinguish from collection names
    # Regex pattern for resource IDs:
    # - Starts with a slash
    # - May have zero or more alphanumeric characters
    # - Must contain at least one digit, underscore, or hyphen (to distinguish from collection names)
    # - May have additional alphanumeric, underscore, or hyphen characters
    # - Optional trailing slash
    DEFAULT_RESOURCE_ID_PATTERN = %r{
      /                # Starts with a slash
      [a-zA-Z0-9]*     # Zero or more alphanumeric characters
      [0-9_-]+         # At least one digit, underscore, or hyphen
      [a-zA-Z0-9_-]*   # Zero or more alphanumeric, underscore, or hyphen characters
      /?               # Optional trailing slash
      $                # End of string
    }x

    # Hop-by-hop headers that should not be forwarded by proxies (RFC 2616/7230)
    HOP_BY_HOP_HEADERS = %w[
      CONNECTION
      KEEP-ALIVE
      PROXY-AUTHENTICATE
      PROXY-AUTHORIZATION
      TE
      TRAILERS
      TRANSFER-ENCODING
      UPGRADE
    ].freeze

    def initialize(origin, cache, resource_id_pattern: DEFAULT_RESOURCE_ID_PATTERN)
      @origin = origin
      @cache = cache
      @resource_id_pattern = resource_id_pattern
    end

    def call(env)
      request_method = env['REQUEST_METHOD']
      path_info = env['PATH_INFO']
      query_string = env['QUERY_STRING']

      # Handle admin endpoints
      if path_info.start_with?('/__cache__')
        return handle_admin_request(env)
      end

      # Check if method is supported
      unless %w[GET HEAD POST PUT DELETE PATCH OPTIONS].include?(request_method)
        return [405, {}, ['Method Not Allowed']]
      end

      url = "#{@origin}#{path_info}"
      url += "?#{query_string}" unless query_string.nil? || query_string.empty?
      cache_key = "#{request_method}:#{url}"

      # Only check cache for cacheable methods
      cached = nil
      if cacheable_method?(request_method)
        cached = @cache.get(cache_key)
        cache_control_directives = cached ? parse_cache_control(cached[:headers]) : []

        # If cached and not marked no-cache, serve from cache
        if cached && !cache_control_directives.include?('no-cache')
          return [cached[:status], cached[:headers].merge('X-Cache' => 'HIT'), [cached[:body]]]
        end
      end

      # Forward request to origin (with conditional headers for cached requests)
      uri = URI.parse(url)
      req = create_request(request_method, uri, env)
      add_conditional_headers(req, cached) if cached
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      response = http.request(req)

      body = response.body
      headers = extract_headers(response)
      directives = parse_cache_control(headers)
      ttl = extract_ttl(directives)

      # If 304 Not Modified, serve cached response
      if response.code.to_i == 304 && cached
        return [cached[:status], cached[:headers].merge('X-Cache' => 'REVALIDATED'), [cached[:body]]]
      end

      # If no-store, do not cache at all (early return)
      if directives.include?('no-store')
        return [response.code.to_i, headers.merge('X-Cache' => 'NO-STORE'), [body]]
      end

      # If no-cache, do not cache, but set header to BYPASS
      if directives.include?('no-cache')
        return [response.code.to_i, headers.merge('X-Cache' => 'BYPASS'), [body]]
      end

      # Handle cache invalidation for non-GET methods
      if !cacheable_method?(request_method) && response.code.to_i < 400
        invalidate_related_cache(url, request_method)
      end

      # Store in cache only for cacheable methods and successful responses
      x_cache = 'MISS'
      if cacheable_method?(request_method) && should_cache_response?(response.code.to_i, directives)
        @cache.set(cache_key, { status: response.code.to_i, headers: headers, body: body }, ttl)
      else
        x_cache = cacheable_method?(request_method) ? 'BYPASS' : 'UNCACHEABLE'
      end

      [response.code.to_i, headers.merge('X-Cache' => x_cache), [body]]
    end

    private

    def handle_admin_request(env)
      request_method = env['REQUEST_METHOD']
      path_info = env['PATH_INFO']
      query_string = env['QUERY_STRING']

      case path_info
      when '/__cache__/stats'
        return handle_cache_stats(request_method)
      when '/__cache__/keys'
        return handle_cache_keys(request_method)
      when '/__cache__/clear'
        return handle_cache_clear(request_method)
      when '/__cache__/invalidate'
        return handle_cache_invalidate(request_method, query_string)
      else
        return [404, {}, ['Admin endpoint not found']]
      end
    end

    def handle_cache_stats(method)
      return [405, {}, ['Method Not Allowed']] unless method == 'GET'

      stats = @cache.stats
      response_body = JSON.generate(stats)
      [200, {'Content-Type' => 'application/json'}, [response_body]]
    end

    def handle_cache_keys(method)
      return [405, {}, ['Method Not Allowed']] unless method == 'GET'

      keys = @cache.keys
      response_body = JSON.generate({ keys: keys, count: keys.size })
      [200, {'Content-Type' => 'application/json'}, [response_body]]
    end

    def handle_cache_clear(method)
      return [405, {}, ['Method Not Allowed']] unless method == 'POST'

      @cache.clear
      response_body = JSON.generate({ message: 'Cache cleared successfully' })
      [200, {'Content-Type' => 'application/json'}, [response_body]]
    end

    def handle_cache_invalidate(method, query_string)
      return [405, {}, ['Method Not Allowed']] unless method == 'POST'

      params = parse_query_string(query_string)

      if params['key']
        result = @cache.invalidate(params['key'])
        message = result ? 'Key invalidated successfully' : 'Key not found'
        response_body = JSON.generate({ message: message, key: params['key'] })
      elsif params['pattern']
        deleted_keys = @cache.invalidate_pattern(params['pattern'])
        response_body = JSON.generate({
          message: "#{deleted_keys.size} keys invalidated",
          pattern: params['pattern'],
          deleted_keys: deleted_keys
        })
      else
        return [400, {}, ['Missing key or pattern parameter']]
      end

      [200, {'Content-Type' => 'application/json'}, [response_body]]
    end

    def parse_query_string(query_string)
      return {} if query_string.nil? || query_string.empty?

      params = {}
      query_string.split('&').each do |pair|
        key, value = pair.split('=', 2)
        params[URI.decode_www_form_component(key)] = URI.decode_www_form_component(value || '')
      end
      params
    end

    def cacheable_method?(method)
      %w[GET HEAD OPTIONS].include?(method)
    end

    def should_cache_response?(status_code, directives)
      # Don't cache error responses
      return false if status_code >= 400

      # Don't cache if explicitly marked as no-store
      return false if directives.include?('no-store')

      # Cache successful responses
      status_code >= 200 && status_code < 300
    end

    def create_request(method, uri, env)
      case method
      when 'GET'
        Net::HTTP::Get.new(uri.request_uri)
      when 'HEAD'
        Net::HTTP::Head.new(uri.request_uri)
      when 'POST'
        req = Net::HTTP::Post.new(uri.request_uri)
        req.body = read_request_body(env)
        req
      when 'PUT'
        req = Net::HTTP::Put.new(uri.request_uri)
        req.body = read_request_body(env)
        req
      when 'DELETE'
        Net::HTTP::Delete.new(uri.request_uri)
      when 'PATCH'
        req = Net::HTTP::Patch.new(uri.request_uri)
        req.body = read_request_body(env)
        req
      when 'OPTIONS'
        Net::HTTP::Options.new(uri.request_uri)
      else
        raise "Unsupported HTTP method: #{method}"
      end.tap do |request|
        # Copy headers from original request
        copy_request_headers(env, request)
      end
    end

    def read_request_body(env)
      input = env['rack.input']
      return '' unless input

      body = input.read
      input.rewind
      body
    end

    def copy_request_headers(env, request)
      env.each do |key, value|
        if key.start_with?('HTTP_')
          header_name = key[5..-1].tr('_', '-')
          # Skip hop-by-hop headers and host header (will be set by Net::HTTP)
          next if hop_by_hop_header?(header_name) || header_name.upcase == 'HOST'
          request[header_name] = value
        elsif %w[CONTENT_TYPE CONTENT_LENGTH].include?(key)
          request[key.tr('_', '-')] = value
        end
      end
    end

    def invalidate_related_cache(url, method)
      case method
      when 'POST'
        # POST to /users might invalidate /users cache
        base_url = url.gsub(/\?.*$/, '') # Remove query string
        @cache.invalidate_pattern("GET:#{base_url}*")
      when 'PUT', 'PATCH'
        # PUT/PATCH to /users/abc123 should invalidate /users/abc123 and possibly /users
        @cache.invalidate_pattern("GET:#{url}")
        # Also invalidate collection if this looks like a resource update
        if url =~ @resource_id_pattern
          collection_url = url.gsub(@resource_id_pattern, '')
          @cache.invalidate_pattern("GET:#{collection_url}*")
        end
      when 'DELETE'
        # DELETE to /users/abc123 should invalidate /users/abc123 and /users
        @cache.invalidate_pattern("GET:#{url}")
        if url =~ @resource_id_pattern
          collection_url = url.gsub(@resource_id_pattern, '')
          @cache.invalidate_pattern("GET:#{collection_url}*")
        end
      end
    end

    def parse_cache_control(headers)
      cc = headers['cache-control'] || headers['Cache-Control']
      return [] if cc.nil? || cc.to_s.strip.empty?
      cc.to_s.downcase.split(',').map(&:strip)
    end

    def extract_ttl(directives)
      max_age = directives.find { |d| d.start_with?('max-age=') }
      return nil unless max_age
      val = max_age.split('=', 2)[1]
      val =~ /^\d+$/ ? val.to_i : nil
    end

    def add_conditional_headers(req, cached)
      return unless cached && cached[:headers]
      if cached[:headers]['etag']
        req['If-None-Match'] = cached[:headers]['etag']
      end
      if cached[:headers]['last-modified']
        req['If-Modified-Since'] = cached[:headers]['last-modified']
      end
    end

    def hop_by_hop_header?(header_name)
      HOP_BY_HOP_HEADERS.include?(header_name.to_s.upcase)
    end

    def extract_headers(response)
      headers = {}
      response.each_header do |k, v|
        # Don't forward hop-by-hop headers back to client
        headers[k] = v unless hop_by_hop_header?(k)
      end
      headers
    end
  end
end
