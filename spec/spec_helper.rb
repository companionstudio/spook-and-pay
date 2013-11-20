require 'bundler/setup'
require 'rspec'
require 'httparty'
require 'spook_and_pay'
require 'debugger'
require 'rack'
require './spec/env' if File.exists?('spec/env.rb')

module RequestHelpers
  # A method which constructs a 'fake' form and submits to a provider, which it
  # then turns into a Rack::MockRequest.
  #
  # @param Hash definition
  # @param Hash vals
  #
  # @return Rack::MockRequest
  def provider_request(definition, vals = {})
    pairs = {
      :name             => "China McPants",
      :number           => 4111111111111111,
      :expiration_month => 9,
      :expiration_year  => 2016,
      :cvv              => 163
    }.merge(vals).map {|k, v| [definition[:field_names][k], v]}

    body = Hash[*pairs.flatten].merge(definition[:hidden_fields])

    begin
      response = HTTParty.post(definition[:url], :body => body, :no_follow  => true)
    rescue HTTParty::RedirectionTooDeep => e
      match = e.response.body.match(/href="(.*?)"/)
      if match
        Rack::MockRequest.env_for(CGI.unescapeHTML(match[1]))
      else
        raise "Could not find token on response:\n #{e.response.body}"
      end
    end
  end
end

RSpec.configure do |config|
  include RequestHelpers
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end
