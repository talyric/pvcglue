# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pvcglue/version'

Gem::Specification.new do |spec|
  spec.name          = 'pvcglue'
  spec.version       = Pvcglue::VERSION
  spec.authors       = ['T. Andrew Lyric']
  spec.email         = ['talyric@gmail.com']
  spec.description   = %q{PVC_Glue description}
  spec.summary       = %q{PVC_Glue summary}
  spec.homepage      = 'https://github.com/talyric/pvcglue'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '>= 1.3.0', '< 2.0'
  spec.add_development_dependency 'rake', '~> 10.1'
  spec.add_development_dependency 'byebug'
  # spec.add_development_dependency 'pry'

  spec.add_dependency 'thor', '~> 0.19', '>= 0.19.1'
  spec.add_dependency 'toml-rb', '~> 0.3', '>= 0.3.15'
  # spec.add_dependency 'orca', '= 0.4', '= 0.4.0'
  spec.add_dependency 'capistrano', '~> 3.4.0', '>= 3.4.1'
  spec.add_dependency 'capistrano-bundler', '~> 1.1', '>= 1.1.1'
  spec.add_dependency 'capistrano-rails', '~> 1.1', '>= 1.1.1'
  spec.add_dependency 'capistrano-rvm', '~> 0.1', '>= 0.1.1'
  spec.add_dependency 'sshkit', '~> 1.3', '>= 1.3.0'
  spec.add_dependency 'awesome_print'
  spec.add_dependency 'hashie'
  # spec.add_dependency 'droplet_kit'
  spec.add_dependency 'paint'
  spec.add_dependency 'tilt'

end
