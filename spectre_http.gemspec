# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'spectre-http'
  spec.version       = '2.0.1'
  spec.authors       = ['Christian Neubauer']
  spec.email         = ['christian.neubauer@ionos.com']

  spec.summary       = 'Standalone HTTP wrapper compatible with spectre'
  spec.description   = 'A HTTP wrapper for nice readability. Is compatible with spectre-core.'
  spec.homepage      = 'https://github.com/ionos-spectre/spectre-http'
  spec.license       = 'GPL-3.0-or-later'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/ionos-spectre/spectre-http'
  spec.metadata['changelog_uri']   = 'https://github.com/ionos-spectre/spectre-http/blob/master/CHANGELOG.md'

  spec.files = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.add_dependency 'ectoplasm'
  spec.add_dependency 'jsonpath'
  spec.add_dependency 'logger'
  spec.add_dependency 'ostruct'
end
