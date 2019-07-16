$:.push File.expand_path("../lib/spook_and_pay", __FILE__)

Gem::Specification.new do |s|
  s.name        = "spook_and_pay"
  s.version     = "1.1.3"
  s.authors     = ["Ben Hull"]
  s.email       = ["ben@companionstudio.com.au"]
  s.homepage    = "https://github.com/companionstudio/spook-and-pay"
  s.summary     = "A library for handling online payments using services providing transparent redirects."
  s.license     = "MIT"

  s.files = Dir["lib/**/*"] + ["README.md", "LICENSE"]

  s.add_dependency              'braintree',  '2.92.0'
  s.add_dependency              'spreedly',   '2.0.18'
  s.add_dependency              'rack',       '>= 2'
  s.add_development_dependency  'rspec',      '2.14.1'
  s.add_development_dependency  'httparty',   '0.11.0'
end
