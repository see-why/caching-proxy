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
      key = @origin

      if @cache.key? key
        cached = @cache[key]
        return [cached[:status], cached[:headers].merge('X-Cache' => 'HIT'), [cached[:body]]]
      end

      uri = URI.new(@origin)
      response = Net::HTTP.get_response(uri)

      body = response.body
      headers = {}
      response.each_header { |k, v| headers[k] = v }

      @cache.set(key, { status: response.code.to_i, headers: headers, body: body })

      [response.code.to_i, headers.merge('X-Cache' => 'MISS'), [body]]
    end
  end
end
