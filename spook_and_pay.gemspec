$:.push File.expand_path("../lib/spook_and_pay", __FILE__)

Gem::Specification.new do |s|
  s.name        = "spook_and_pay"
  s.version     = "1.1.2"
  s.authors     = ["Luke Sutton", "Ben Hull"]
  s.email       = ["lukeandben@spookandpuff.com"]
  s.homepage    = "http://spookandpuff.com"
  s.summary     = "A library for handling online payments using services providing transparent redirects."

  s.files = Dir["lib/**/*"] + ["README.md", "LICENSE"]

  s.add_dependency              'braintree',  '2.80.1'
  s.add_dependency              'spreedly',   '2.0.6'
  s.add_dependency              'rack',       '>= 1.4.0'
  s.add_development_dependency  'rspec',      '2.14.1'
  s.add_development_dependency  'httparty',   '0.11.0'
end
