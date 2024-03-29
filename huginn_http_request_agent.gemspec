# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "huginn_http_request_agent"
  spec.version       = "1.3.0"
  spec.authors       = ["Jacob Spizziri"]
  spec.email         = ["jspizziri@weare5stones.com"]

  spec.summary       = %q{The Http Request Agent is intended to be an abstract agent that allows for the interaction of any http service.}
  spec.description   = %q{The Http Request Agent is intended to be an abstract agent that allows for the interaction of any http service.}

  spec.homepage      = "https://github.com/5-stones/huginn_http_request_agent"

  spec.license       = "MIT"


  spec.files         = Dir['LICENSE.txt', 'lib/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = Dir['spec/**/*.rb'].reject { |f| f[%r{^spec/huginn}] }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "huginn_agent"
end
