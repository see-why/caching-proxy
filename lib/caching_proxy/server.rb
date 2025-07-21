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

      @cache.set(url, { status: response.code.to_i, headers: headers, body: body })

      [response.code.to_i, headers.merge('X-Cache' => 'MISS'), [body]]
    end
  end
end
