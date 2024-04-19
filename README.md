# Spectre HTTP `spectre/http`

[![Build](https://github.com/ionos-spectre/spectre-http/actions/workflows/build.yml/badge.svg)](https://github.com/ionos-spectre/spectre-http/actions/workflows/build.yml)
[![Gem Version](https://badge.fury.io/rb/spectre-http.svg)](https://badge.fury.io/rb/spectre-http)

This is a [spectre](https://github.com/ionos-spectre/spectre-core) module which provides HTTP request functionality to the spectre framework.


## Install

```bash
$ sudo gem install spectre-http
```


## Usage

```ruby
http 'dummy.restapiexample.com/api/v1/' do
  method 'GET'
  path 'employee/1'

  param 'foo', 'bar'
  param 'bla', 'blubb'

  header 'X-Authentication', '*****'
  header 'X-Correlation-Id', ''

  content_type 'plain/text'
  body 'Some plain text body content'

  # Adds a JSON body with content type application/json
  json({
    "message": "Hello Spectre!"
  })
end
```

You can also use `https` to enable SSL requests.

```ruby
https 'dummy.restapiexample.com/api/v1/' do
  method 'GET'
  path 'employee/1'
end
```

The parameter can either be a valid URL or a name of the config section in your environment file in `http`.

Example:

```yaml
http:
  dummy_api:
    base_url: http://dummy.restapiexample.com/api/v1/
```

In order to do requests with this HTTP client, use the `http` or `https` helper function.

```ruby
http 'dummy_api' do
  method 'GET'
  path 'employee/1'
end
```

When using `https` it will override the protocol specified in the config.

You can set the following properties in the `http` block:

| Method | Arguments | Multiple | Description |
| -------| ----------| -------- | ----------- |
| `method` | `string` | no | The HTTP request method to use. Usually one of `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`, `HEAD` |
| `url` | `string` | no | Overrides the `base_url` for the HTTP request |
| `param` | `string`,`string` | yes | Adds a query parameter to the request |
| `path` | `string` | no | The URL path to request |
| `json` | `Hash` | no | Adds the given hash as json and sets content type to `application/json` |
| `body` | `string` | no | The request body to send |
| `header` | `string`,`string` | yes | Adds a header to the request |
| `content_type` | `string` | no | Sets the `Content-Type` header to the given value |
| `ensure_success!` | *none* | no | Will raise an error, when the response code does not indicate success (codes >= 400). |
| `auth` | `string` | no | The given authentication module will be used. Currently `basic_auth` and `keystone` are available. |
| `timeout` | `integer` | no | The request timeout in seconds. *default: 180* |
| `retries` | `integer` | no | Internal request retry after timeout. *default: 0* |
| `no_auth!` | *none* | no | Deactivates the configured auth method |
| `certificate` | `string` | no | The file path to the certificate to use for request validation |
| `use_ssl!` | *none* | no | Enables HTTPS |
| `no_log!` | *none* | no | If `true` request and response bodies will not be logged. Use this, when handling sensitive, binary or large response and request data. |


Access the response with the `response` function. This returns an object with the following properties:

| Method | Description |
| -------| ----------- |
| `code` | The response code of the HTTP request |
| `message` | The status message of the HTTP response, e.g. `Ok` or `Bad Request` |
| `body` | The plain response body as a string |
| `json` | The response body as JSON data of type `OpenStruct` |
| `headers` | The response headers as a dictionary. Header values can be accessed with `response.headers['Server']`. The header key is case-insensitive. |

```ruby
response.code.should_be 200
response.headers['server'].should_be 'nginx'
```

#### Basic Auth `spectre/http/basic_auth`

Adds `basic_auth` to the HTTP module.

```ruby
http 'dummy_api' do
  basic_auth 'someuser', 'somepassword'
  method 'GET'
  path 'employee/1'
end
```

You can also add basic auth config options to your `spectre.yml` or environment files.

```yaml
http:
  dummy_api:
    base_url: http://dummy.restapiexample.com/api/v1/
    basic_auth:
      username: 'dummy'
      password: 'someawesomepass'
```

And tell the client to use basic auth.

```ruby
http 'dummy_api' do
  auth 'basic_auth' # add this to use basic auth
  method 'GET'
  path 'employee/1'
end
```

#### Keystone `spectre/http/keystone`

Adds keystone authentication to the HTTP client.

Add keystone authentication option to the http client in your `spectre.yml`

```yaml
http:
  dummy_api:
    base_url: http://dummy.restapiexample.com/api/v1/
    keystone:
      url: https://some-keystone-server:5000/main/v3/
      username: dummy
      password: someawesomepass
      project: some_project
      domain: some_domain
      cert: path/to/cert
```

And tell the client to use *keystone* authentication.

```ruby
http 'dummy_api' do
  auth 'keystone' # add this to use keystone
  method 'GET'
  path 'employee/1'
end
```

You can also use the `keystone` function, to use keystone authentication directly from the `http` block

```ruby
http 'dummy_api' do
  method 'GET'
  path 'employee/1'
  keystone 'https://some-keystone-server:5000/main/v3/', 'dummy', 'someawesomepass', 'some_project', 'some_domain', 'path/to/cert'
end
```