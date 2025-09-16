require_relative 'lib/vagrant-eryph/version'

Gem::Specification.new do |spec|
  spec.name          = 'vagrant-eryph'
  spec.version       = VagrantPlugins::Eryph::VERSION
  spec.authors       = ['dbosoft and eryph contributors']
  spec.email         = ['package-maintainers@eryph.io']
  
  spec.summary       = 'Vagrant provider for Eryph'
  spec.description   = 'A Vagrant provider plugin that allows you to manage catlets using Eryph\'s compute API'
  spec.homepage      = 'https://github.com/eryph-org/vagrant-eryph'
  spec.license       = 'MIT'
  
  spec.required_ruby_version = '>= 3.1.0'
  
  spec.files = Dir.glob('lib/**/*') + %w[README.md LICENSE vagrant-eryph.gemspec]
  spec.require_paths = ['lib']
  
  spec.add_dependency 'eryph-compute', '~> 0.1.1'
  spec.add_dependency 'eryph-clientruntime', '~> 0.1'
  spec.add_dependency 'log4r', '~> 1.1'
  
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.6'
end