# frozen_string_literal: true

require 'net/http'
require 'uri'


module CachingProxy
  class Server
    def initialize(origin, cache)
      @origin = origin
      @cache = cache
    end

    def call(env)
      request_method = env['REQUEST_METHOD']
      return [405, {}, ['Method Not Allowed']] unless request_method == 'GET'

      path_info = env['PATH_INFO']
      query_string = env['QUERY_STRING']

      url = "#{@origin}#{path_info}"
      url += "?#{query_string}" unless query_string.nil? || query_string.empty?

      cached = @cache.get(url)
      cache_control_directives = cached ? parse_cache_control(cached[:headers]) : []

      # If cached and not marked no-cache, serve from cache
      if cached && !cache_control_directives.include?('no-cache')
        return [cached[:status], cached[:headers].merge('X-Cache' => 'HIT'), [cached[:body]]]
      end

      # If cached and marked no-cache, revalidate with origin
      uri = URI.parse(url)
      req = Net::HTTP::Get.new(uri)
      add_conditional_headers(req, cached)
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

      # Store in cache (normal case)
      @cache.set(url, { status: response.code.to_i, headers: headers, body: body }, ttl)

      # If max-age, set MISS, else default
      x_cache = 'MISS'
      [response.code.to_i, headers.merge('X-Cache' => x_cache), [body]]
    end

    private

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

    def extract_headers(response)
      headers = {}
      response.each_header { |k, v| headers[k] = v if k.to_s.downcase != 'transfer-encoding' }
      headers
    end
  end
end
