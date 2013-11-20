require 'spec_helper'

describe "Spreedly transactions" do
  before(:all) do
    @provider = SpookAndPay::Providers::Spreedly.new(
      :development,
      :environment_key => ENV["SPREEDLY_ENVIRONMENT_KEY"],
      :access_secret   => ENV["SPREEDLY_ACCESS_SECRET"],
      :gateway_token   => ENV["SPREEDLY_GATEWAY_TOKEN"]
    )
  end

  it "should authorize a purchase" do
    
  end

  it "should capture authorized funds"
  it "should refund"
  it "should void"
end
