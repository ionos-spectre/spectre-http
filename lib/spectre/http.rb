require 'net/http'
require 'openssl'
require 'json'
require 'jsonpath'
require 'yaml'
require 'securerandom'
require 'logger'
require 'ostruct'
require 'ectoplasm'

class ::String
  def pick path
    raise ArgumentError, "`path' must not be nil or empty" if path.nil? or path.empty?

    begin
      JsonPath.on(self, path)
    rescue MultiJson::ParseError
      # do nothing and return nil
    end
  end
end

class ::OpenStruct
  def pick path
    raise ArgumentError, "`path' must not be nil or empty" if path.nil? or path.empty?

    JsonPath.on(self, path)
  end
end

module Spectre
  module Http
    DEFAULT_HTTP_CONFIG = {
      'method' => 'GET',
      'path' => '',
      'host' => nil,
      'port' => 80,
      'scheme' => 'http',
      'use_ssl' => false,
      'cert' => nil,
      'headers' => [],
      'query' => [],
      'params' => {},
      'content_type' => nil,
      'timeout' => 180,
      'retries' => 0,
    }

    class SpectreHttpError < StandardError
    end

    class SpectreHttpRequest
      include Spectre::Delegate if defined? Spectre::Delegate

      class Headers
        CONTENT_TYPE = 'Content-Type'
        UNIQUE_HEADERS = [CONTENT_TYPE].freeze
      end

      def initialize request
        @__req = request
      end

      def endpoint name
        @__req['endpoint'] = name
      end

      def method method_name
        @__req['method'] = method_name.upcase
      end

      [:get, :post, :put, :patch, :delete].each do |method|
        define_method(method) do |url_path|
          @__req['method'] = method.to_s.upcase
          @__req['path'] = url_path
        end
      end

      def url base_url
        @__req['base_url'] = base_url
      end

      def path url_path
        @__req['path'] = url_path
      end

      def basic_auth username, password
        @__req['basic_auth'] = {
          'username' => username,
          'password' => password,
        }
      end

      def timeout seconds
        @__req['timeout'] = seconds
      end

      def retries count
        @__req['retries'] = count
      end

      def header name, value
        @__req['headers'].append [name.to_sym, value.to_s.strip]
      end

      def query name = nil, value = nil, **kwargs
        @__req['query'].append [name, value.to_s.strip] unless name.nil?
        @__req['query'] += kwargs.map { |key, val| [key.to_s, val] } if kwargs.any?
      end

      # This alias is deprecated and should not be used anymore
      # in favor on +query+ as it conflicts with the route +params+ property
      alias param query

      def with **params
        @__req['params'].merge! params
      end

      def content_type media_type
        @__req['content_type'] = media_type
      end

      def json data
        body JSON.pretty_generate(data)

        content_type('application/json') unless @__req['content_type']
      end

      def body body_content
        @__req['body'] = body_content.to_s
      end

      def ensure_success!
        @__req['ensure_success'] = true
      end

      def ensure_success?
        @__req['ensure_success']
      end

      def authenticate method
        @__req['auth'] = method
      end

      def no_auth!
        @__req['auth'] = 'none'
      end

      def certificate path
        @__req['cert'] = path
      end

      def use_ssl!
        @__req['use_ssl'] = true
      end

      def no_log!
        @__req['no_log'] = true
      end

      def to_s
        @__req.to_s
      end

      alias auth authenticate
      alias cert certificate
      alias media_type content_type
    end

    class SpectreHttpHeader
      def initialize headers
        @headers = headers || {}
      end

      def [] key
        return nil unless @headers.key?(key.downcase)

        @headers[key.downcase].first
      end

      def to_s
        @headers.to_s
      end
    end

    class SpectreHttpResponse
      attr_reader :code, :message, :headers, :body, :json

      def initialize net_res
        @code = net_res.code.to_i
        @message = net_res.message
        @body = net_res.body
        @headers = SpectreHttpHeader.new(net_res.to_hash)
        @json = nil

        return if @body.nil?

        begin
          @json = JSON.parse(@body, object_class: OpenStruct)
        rescue JSON::ParserError
          # Shhhhh... it's ok. Do nothing here
        end
      end

      def success?
        @code < 400
      end
    end

    PROGNAME = 'spectre/http'
    MODULES = []
    DEFAULT_SECURE_KEYS = ['password', 'pass', 'token', 'secret', 'key', 'auth',
                           'authorization', 'cookie', 'session', 'csrf', 'jwt', 'bearer']

    class Client
      def initialize config, logger
        @config = config['http']
        @logger = logger
        @debug = config['debug'] || false
        @openapi_cache = {}
      end

      def https(name, &)
        http(name, secure: true, &)
      end

      def http(name, secure: false, &)
        req = Marshal.load(Marshal.dump(DEFAULT_HTTP_CONFIG))

        if @config.key? name
          deep_merge(req, Marshal.load(Marshal.dump(@config[name])))

          unless req['base_url']
            raise SpectreHttpError, "No `base_url' set for HTTP client '#{name}'. " \
                                    'Check your HTTP config in your environment.'
          end
        else
          req['base_url'] = name
        end

        req['use_ssl'] = secure unless secure.nil?

        SpectreHttpRequest.new(req).instance_eval(&) if block_given?

        invoke(req)
      end

      def request
        req = Thread.current.thread_variable_get(:request)

        raise 'No request has been invoked yet' unless req

        req
      end

      def response
        res = Thread.current.thread_variable_get(:response)

        raise 'No response has been received yet' unless res

        res
      end

      private

      def deep_merge(first, second)
        return unless second.is_a?(Hash)

        merger = proc { |_key, v1, v2| v1.is_a?(Hash) && v2.is_a?(Hash) ? v1.merge!(v2, &merger) : v2 }
        first.merge!(second, &merger)
      end

      def try_format_json json, pretty: false
        return json unless json or json.empty?

        if json.is_a? String
          begin
            json = JSON.parse(json)
          rescue StandardError
            # do nothing
          end
        end

        json.obfuscate!(DEFAULT_SECURE_KEYS) unless @debug
        pretty ? JSON.pretty_generate(json) : JSON.dump(json)
      end

      def secure? key
        DEFAULT_SECURE_KEYS.any? { |x| key.to_s.downcase.include? x.downcase }
      end

      def header_to_s headers
        s = ''
        headers.each_header.each do |header, value|
          value = '*****' if secure?(header) and !@debug
          s += "#{header.to_s.ljust(30, '.')}: #{value}\n"
        end
        s
      end

      def load_openapi config
        path = config['openapi']

        return @openapi_cache[path] if @openapi_cache.key? path

        content = if path.match 'http[s]?://'
                    Net::HTTP.get URI(path)
                  else
                    File.read(path)
                  end

        openapi = YAML.safe_load(content)

        config['endpoints'] = {}

        openapi['paths'].each do |uri_path, path_config|
          path_config.each do |method, endpoint|
            config['endpoints'][endpoint['operationId']] = {
              'method' => method.upcase,
              'path' => uri_path,
            }
          end
        end

        @openapi_cache[path] = config['endpoints']
      end

      def invoke req
        Thread.current.thread_variable_set(:request, nil)

        # Build URI

        scheme = req['use_ssl'] ? 'https' : 'http'
        base_url = req['base_url']

        base_url = "#{scheme}://#{base_url}" unless base_url.match %r{http(?:s)?://}

        if req.key? 'endpoint'
          load_openapi(req) if req.key? 'openapi'

          raise 'no endpoints configured' unless req.key? 'endpoints'

          endpoint = req['endpoints'][req['endpoint']] or raise 'endpoint not found'
          endpoint = Marshal.load(Marshal.dump(endpoint))

          req.merge! endpoint
        end

        method = req['method'] || 'GET'
        path = req['path']

        if path
          base_url += '/' unless base_url.end_with? '/'
          path = path[1..] if path.start_with? '/'
          base_url += path

          req['params'].each do |key, val|
            base_url.gsub! "{#{key}}", val.to_s
          end
        end

        uri = URI(base_url)

        raise SpectreHttpError, "'#{uri}' is not a valid uri" unless uri.host

        # Build query parameters

        uri.query = URI.encode_www_form(req['query']) unless !req['query'] or req['query'].empty?

        # Create HTTP client

        net_http = Net::HTTP.new(uri.host, uri.port)
        net_http.read_timeout = req['timeout']
        net_http.max_retries = req['retries']

        if uri.scheme == 'https'
          net_http.use_ssl = true

          if req['cert']
            raise SpectreHttpError, "Certificate '#{req['cert']}' does not exist" unless File.exist? req['cert']

            net_http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            net_http.ca_file = req['cert']
          else
            net_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end
        end

        # Create HTTP Request

        net_req = Net::HTTPGenericRequest.new(method, true, true, uri)
        body = req['body']
        body = JSON.dump(body) if body.is_a? Hash
        net_req.body = body
        net_req.content_type = req['content_type'] if req['content_type'] and !req['content_type'].empty?
        net_req.basic_auth(req['basic_auth']['username'], req['basic_auth']['password']) if req.key? 'basic_auth'

        req['headers']&.each do |header|
          net_req[header[0]] = header[1]
        end

        req_id = SecureRandom.uuid[0..5]

        # Run HTTP modules

        MODULES.each do |mod|
          mod.on_req(net_http, net_req, req) if mod.respond_to? :on_req
        end

        # Log request

        req_log = "[>] #{req_id} #{method} #{uri}\n"
        req_log += header_to_s(net_req)

        unless req['body'].nil? or req['body'].empty?
          req_log += req['no_log'] ? '[...]' : try_format_json(req['body'], pretty: true)
        end

        @logger.log(Logger::Severity::INFO, req_log, PROGNAME)

        # Request

        start_time = Time.now

        begin
          net_res = net_http.request(net_req)
        rescue SocketError => e
          raise SpectreHttpError, "The request '#{method} #{uri}' failed: #{e.message}\n" \
                                  "Please check if the given URL '#{uri}' is valid " \
                                  'and available or a corresponding HTTP config in ' \
                                  'the environment file exists. See log for more details. '
        rescue Net::ReadTimeout
          raise SpectreHttpError, "HTTP timeout of #{net_http.read_timeout}s exceeded"
        end

        end_time = Time.now

        req['started_at'] = start_time
        req['finished_at'] = end_time

        # Run HTTP modules

        MODULES.each do |mod|
          mod.on_res(net_http, net_res, req) if mod.respond_to? :on_res
        end

        # Log response

        res_log = "[<] #{req_id} #{net_res.code} #{net_res.message} (#{end_time - start_time}s)\n"
        res_log += header_to_s(net_res)

        unless net_res.body.nil? or net_res.body.empty?
          res_log += req['no_log'] ? '[...]' : try_format_json(net_res.body, pretty: true)
        end

        @logger.log(Logger::Severity::INFO, res_log, PROGNAME)

        if req['ensure_success'] and net_res.code.to_i >= 400
          raise "Response code of #{req_id} did not indicate success: #{net_res.code} #{net_res.message}"
        end

        Thread.current.thread_variable_set(:request, OpenStruct.new(req).freeze)
        Thread.current.thread_variable_set(:response, SpectreHttpResponse.new(net_res).freeze)
      end
    end
  end

  Engine.register(Http::Client, :http, :https, :request, :response) if defined? Engine
end
