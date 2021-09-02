# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
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
    'Francisco Juan',
    'Tommy Gustafsson',
    'Daniel Orner'
  ]
  spec.email = [
    'ornelas.tulio@gmail.com',
    'mathias.klippinge@gmail.com',
    'sergey.evstifeev@gmail.com',
    'ticolucci@gmail.com',
    'martin@lite.nu',
    'francisco.juan@gmail.com',
    'tommydgustafsson@gmail.com',
    'dmorner@gmail.com'
  ]

  spec.summary       = 'Simplifying Kafka for ruby apps'
  spec.description   = 'Phobos is a microframework and library for kafka based applications, '\
    'it wraps common behaviors needed by consumers/producers in an easy an convenient API. '\
    'It uses ruby-kafka as its kafka client and core component.'
  spec.homepage      = 'https://github.com/klarna/phobos'
  spec.license       = 'Apache License Version 2.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  unless spec.respond_to?(:metadata)
    raise('RubyGems 2.0 or newer is required to protect against public gem pushes.')
  end

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/phobos}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.3'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake', '~> 12.3'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '0.62.0'
  spec.add_development_dependency 'rubocop_rules'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'timecop'

  spec.add_dependency 'activesupport', '>= 3.0.0'
  spec.add_dependency 'concurrent-ruby', '>= 1.0.2'
  spec.add_dependency 'concurrent-ruby-ext', '>= 1.0.2'
  spec.add_dependency 'exponential-backoff'
  spec.add_dependency 'logging'
  spec.add_dependency 'ruby-kafka', '>= 1.4'
  spec.add_dependency 'thor'
end
