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
      path_info = env['PATH_INFO']
      query_string = env['QUERY_STRING']

      puts "request_method: #{request_method}"
      puts "path_info: #{path_info}"
      puts "query_string: #{query_string}"

      url = "#{@origin}#{path_info}"

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
