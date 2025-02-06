require 'stringio'
require 'logger'

# Mock the Spectre modules
module Spectre
  CONFIG = {
    'log_file' => StringIO.new,
    'http' => {
      'example' => {
        'base_url' => 'some-rest-api.io',
        'method' => 'POST',
        'path' => 'some-resource',
        'auth' => 'basic_auth',
        'timeout' => 100,
        'retries' => 3,
        'content_type' => 'application/json',
        'headers' => [
          ['header1', 'value1']
        ],
        'query' => [
          ['key1', 'value1'],
          ['key2', 'value2']
        ],
      },
    },
  }

  class Logger < ::Logger
    def initialize(config, **)
      super(config['log_file'], **)
    end
  end
end

require_relative '../lib/spectre/http'

RSpec.describe 'HTTP' do
  it 'should do some request' do
    net_http = double(Net::HTTP)
    allow(net_http).to receive(:read_timeout=)
    allow(net_http).to receive(:max_retries=)
    allow(net_http).to receive(:use_ssl=)
    allow(net_http).to receive(:verify_mode=)

    net_res = double(Net::HTTPOK)
    allow(net_res).to receive(:code).and_return('200')
    allow(net_res).to receive(:message).and_return('Ok')
    allow(net_res).to receive(:body).and_return('{"result": "Hello RSpec!"}')
    allow(net_res).to receive(:each_header).and_return([['some-header', 'some-value']])
    allow(net_res).to receive(:to_hash).and_return({})

    allow(net_http).to receive(:request).and_return(net_res)

    allow(Net::HTTP).to receive(:new).and_return(net_http)

    net_req = double(Net::HTTPGenericRequest)
    allow(net_req).to receive(:body=)
    allow(net_req).to receive(:basic_auth)
    allow(net_req).to receive(:each_header).and_return([['header1', 'value1']])
    allow(net_req).to receive(:[]=)
    allow(net_req).to receive(:content_type=)
    allow(Net::HTTPGenericRequest).to receive(:new).and_return(net_req)

    expect(net_req).to receive(:body=).with("{\n  \"message\": \"Hello Spectre!\"\n}")
    expect(net_req).to receive(:[]=).with('header1', 'value1')
    expect(net_req).to receive(:content_type=).with('application/json')

    expect(net_http).to receive(:read_timeout=).with(100)
    expect(net_http).to receive(:max_retries=).with(3)
    expect(net_http).to receive(:request).with(net_req)

    Spectre::Http.https 'some-rest-api.io' do
      method 'POST'
      path 'some-resource'
      auth 'basic_auth'
      timeout 100
      retries 3
      content_type 'application/json'
      header 'header1', 'value1'
      param 'key1', 'value1'
      param 'key2', 'value2'
      json({
        message: 'Hello Spectre!',
      })
      ensure_success!
      # body 'foo=bar'
      # use_ssl!                     # request with SSL enabled
      # cert 'path/to/some_ca.cer'   # path to the ca file
      # no_log!                      # don't log request bodies
    end

    expect(Spectre::Http.response.code).to eq 200

    Spectre::Http.https 'example' do
      path 'some-resource'
    end

    expect(Spectre::Http.response.code).to eq 200

    log = Spectre::CONFIG['log_file']
    log.rewind
    lines = log.readlines

    expect(lines[0]).to match('I, \[.*\]  INFO -- spectre/http: \[>\] [a-z0-9]{6} POST ')
    expect(lines[0]).to include('https://some-rest-api.io/some-resource?key1=value1&key2=value2')
    expect(lines[1]).to eq("header1.......................: value1\n")
    expect(lines[2]).to eq("{\n")
    expect(lines[3]).to eq("  \"message\": \"Hello Spectre!\"\n")
    expect(lines[4]).to eq("}\n")
    expect(lines[5]).to match('I, \[.*\]  INFO -- spectre/http: \[<\] [a-z0-9]{6} 200 Ok \([\d\.\-e]+s\)')
    expect(lines[6]).to eq("some-header...................: some-value\n")
    expect(lines[7]).to eq("{\n")
    expect(lines[8]).to eq("  \"result\": \"Hello RSpec!\"\n")
    expect(lines[9]).to eq("}\n")
  end
end
