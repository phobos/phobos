# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'phobos/version'

Gem::Specification.new do |spec|
  spec.name          = 'phobos'
  spec.version       = Phobos::VERSION
  spec.authors       = [
    'Túlio Ornelas',
    'Mathias Klippinge',
    'Sergey Evstifeev',
    'Thiago R. Colucci',
    'Martin Svalin',
    'Francisco Juan'
  ]
  spec.email         = [
    'ornelas.tulio@gmail.com',
    'mathias.klippinge@gmail.com',
    'sergey.evstifeev@gmail.com',
    'ticolucci@gmail.com',
    'martin@lite.nu',
    'francisco.juan@gmail.com'
  ]

  spec.summary       = %q{Simplifying Kafka for ruby apps}
  spec.description   = %q{Phobos is a microframework and library for kafka based applications, it wraps common behaviors needed by consumers/producers in an easy an convenient API. It uses ruby-kafka as its kafka client and core component.}
  spec.homepage      = 'https://github.com/klarna/phobos'
  spec.license       = 'Apache License Version 2.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/phobos}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.3'

  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'pry-byebug', '~> 3.4.0'
  spec.add_development_dependency 'rspec_junit_formatter', '0.2.2'
  spec.add_development_dependency 'simplecov', '~> 0.12.0'
  spec.add_development_dependency 'coveralls', '~> 0.8.15'

  spec.add_dependency 'ruby-kafka', '>= 0.3.13.beta4'
  spec.add_dependency 'concurrent-ruby', '>= 1.0.2'
  spec.add_dependency 'concurrent-ruby-ext', '>= 1.0.2'
  spec.add_dependency 'activesupport', '>= 4.0.0'
  spec.add_dependency 'logging'
  spec.add_dependency 'exponential-backoff'
  spec.add_dependency 'thor'
end
