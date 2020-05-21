$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'helm-cli/version'

Gem::Specification.new do |s|
  s.name     = 'helm-cli'
  s.version  = ::HelmCLI::VERSION
  s.authors  = ['Cameron Dutro']
  s.email    = ['camertron@gmail.com']
  s.homepage = 'http://github.com/camertron/helm-cli'
  s.license  = 'MIT'

  s.description = s.summary = 'Ruby wrapper around the Helm CLI.'

  s.platform = Gem::Platform::RUBY

  s.add_dependency 'helm-rb', '~> 3.0'

  s.require_path = 'lib'
  s.files = Dir['{lib,spec,vendor}/**/*', 'Gemfile', 'CHANGELOG.md', 'README.md', 'Rakefile', 'helm-cli.gemspec']
end
