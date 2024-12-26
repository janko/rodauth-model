# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "rodauth-model"
  spec.version       = "0.4.0"
  spec.authors       = ["Janko Marohnić"]
  spec.email         = ["janko@hey.com"]

  spec.description   = "Provides model mixin for Active Record and Sequel that defines password attribute and associations based on Rodauth configuration."
  spec.summary       = spec.description
  spec.homepage      = "https://github.com/janko/rodauth-model"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.5"

  spec.metadata["source_code_uri"] = "https://github.com/janko/rodauth-model"

  spec.files         = Dir["README.md", "LICENSE.txt", "CHANGELOG.md", "lib/**/*", "*.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rodauth", "~> 2.28"

  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-hooks"
  spec.add_development_dependency "bcrypt"
  spec.add_development_dependency "jwt", "< 2.10"
  spec.add_development_dependency "rotp"
  spec.add_development_dependency "rqrcode"
  spec.add_development_dependency "webauthn" unless RUBY_ENGINE == "jruby"
end
