# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "rodauth-model"
  spec.version       = "0.1.0"
  spec.authors       = ["Janko Marohnić"]
  spec.email         = ["janko@hey.com"]

  spec.description   = "Provides model mixin for Active Record and Sequel that defines password attribute and associations based on Rodauth configuration."
  spec.summary       = spec.description
  spec.homepage      = "https://github.com/janko/rodauth-model"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.4"

  spec.metadata["source_code_uri"] = "https://github.com/janko/rodauth-model"

  spec.files         = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*", "*.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rodauth", "~> 2.0"
end
