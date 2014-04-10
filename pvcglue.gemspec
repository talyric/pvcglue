# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pvcglue/version'

Gem::Specification.new do |spec|
  spec.name          = "pvcglue"
  spec.version       = Pvcglue::VERSION
  spec.authors       = ["Andrew Lyric"]
  spec.email         = ["talyric@gmail.com"]
  spec.description   = %q{PVC_Glue description}
  spec.summary       = %q{PVC_Glue summary}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_dependency "thor"
  spec.add_dependency "toml-rb"
  spec.add_dependency "orca"
end
