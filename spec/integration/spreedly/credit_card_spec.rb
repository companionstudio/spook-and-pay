require 'spec_helper'

describe "Spreedly credit cards" do
  before(:all) do
    @provider = SpookAndPay::Providers::Spreedly.new(
      :development,
      :environment_key => ENV["SPREEDLY_ENVIRONMENT_KEY"],
      :access_secret   => ENV["SPREEDLY_ACCESS_SECRET"],
      :gateway_token   => ENV["SPREEDLY_GATEWAY_TOKEN"]
    )
  end

  def credit_card
    prepare = @provider.prepare_payment_submission("http://localhost", 10)
    response = provider_request(prepare)
    query = Rack::Utils.parse_nested_query(response["QUERY_STRING"])
    result = @provider.confirm_payment_submission(query["token"])
    result.credit_card
  end

  it "should authorize funds" do
    result = credit_card.authorize!(100)
    expect(result.successful?).to eq(true)
  end

  it "should make a purchase" do
    result = credit_card.purchase!(100)
    expect(result.successful?).to eq(true)
  end
end
