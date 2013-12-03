require 'bundler/setup'
require 'rspec'
require 'rspec/mocks'
require 'httparty'
require 'spook_and_pay'
require 'debugger'
require 'rack'

require './spec/support/rspec'
require './spec/support/request_helpers'
require './spec/support/spreedly_helpers'
require './spec/support/braintree_helpers'

require './spec/env' if File.exists?('spec/env.rb')
