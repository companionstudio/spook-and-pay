# encoding: UTF-8
begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rake'
require 'rspec/core'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)
Bundler::GemHelper.install_tasks
task :default => :spec

desc "Run a console with a provider preconfigured"
task :console do 
  require 'irb'
  require 'spook_and_pay'
  require './spec/env' if File.exists?('spec/env.rb')

  if ENV["BRAINTREE_MERCHANT_ID"]
    @braintree = SpookAndPay::Providers::Braintree.new(
      :development,
      :merchant_id  => ENV["BRAINTREE_MERCHANT_ID"],
      :public_key   => ENV["BRAINTREE_PUBLIC_KEY"],
      :private_key  => ENV["BRAINTREE_PRIVATE_KEY"]
    )
  end

  ARGV.clear
  IRB.start
end
