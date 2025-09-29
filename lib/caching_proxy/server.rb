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

      if @cache.key? url
        cached = @cache.get(url)
        return [cached[:status], cached[:headers].merge('X-Cache' => 'HIT'), [cached[:body]]]
      end

      uri = URI.parse(url)
      response = Net::HTTP.get_response(uri)

      body = response.body
      headers = {}
      response.each_header { |k, v| headers[k] = v if k.to_s.downcase != 'transfer-encoding' }

      # Handle Cache-Control headers
      cache_control = headers['cache-control'] || headers['Cache-Control']
      cacheable = true
      ttl = nil
      if cache_control
        directives = cache_control.downcase.split(',').map(&:strip)
        if directives.include?('no-cache') || directives.include?('must-revalidate')
          cacheable = false
        end
        max_age = directives.find { |d| d.start_with?('max-age=') }
        if max_age
          ttl_val = max_age.split('=', 2)[1]
          ttl = ttl_val.to_i if ttl_val =~ /^\d+$/
        end
      end

      if cacheable
        @cache.set(url, { status: response.code.to_i, headers: headers, body: body }, ttl)
      end

      [response.code.to_i, headers.merge('X-Cache' => cacheable ? 'MISS' : 'BYPASS'), [body]]
    end
  end
end
