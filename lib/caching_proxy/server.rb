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
      # If cached and not marked no-cache, serve from cache
      if cached && !(cached[:headers]['cache-control'].to_s.downcase.include?('no-cache'))
        return [cached[:status], cached[:headers].merge('X-Cache' => 'HIT'), [cached[:body]]]
      end

      # If cached and marked no-cache, revalidate with origin
      uri = URI.parse(url)
      req = Net::HTTP::Get.new(uri)
      if cached && cached[:headers]
        if cached[:headers]['etag']
          req['If-None-Match'] = cached[:headers]['etag']
        end
        if cached[:headers]['last-modified']
          req['If-Modified-Since'] = cached[:headers]['last-modified']
        end
      end
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      response = http.request(req)

      body = response.body
      headers = {}
      response.each_header { |k, v| headers[k] = v if k.to_s.downcase != 'transfer-encoding' }

      # Handle Cache-Control headers
      cache_control = headers['cache-control'] || headers['Cache-Control']
      directives = cache_control.to_s.downcase.split(',').map(&:strip)
      max_age = directives.find { |d| d.start_with?('max-age=') }
      ttl = nil
      ttl = max_age.split('=', 2)[1].to_i if max_age && max_age.split('=', 2)[1] =~ /^\d+$/

      # If 304 Not Modified, serve cached response
      if response.code.to_i == 304 && cached
        return [cached[:status], cached[:headers].merge('X-Cache' => 'REVALIDATED'), [cached[:body]]]
      end

      # Store in cache (even if no-cache, but always revalidate before serving)
      @cache.set(url, { status: response.code.to_i, headers: headers, body: body }, ttl)

      # If no-cache, mark as BYPASS, else MISS
      x_cache = directives.include?('no-cache') ? 'BYPASS' : 'MISS'
      [response.code.to_i, headers.merge('X-Cache' => x_cache), [body]]
    end
  end
end
