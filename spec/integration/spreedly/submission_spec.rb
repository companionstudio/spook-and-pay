require 'spec_helper'

describe "Spreedly submission" do
  before(:all) do
    @provider = SpookAndPay::Providers::Spreedly.new(
      :development,
      :environment_key => ENV["SPREEDLY_ENVIRONMENT_KEY"],
      :access_secret   => ENV["SPREEDLY_ACCESS_SECRET"],
      :gateway_token   => ENV["SPREEDLY_GATEWAY_TOKEN"]
    )
  end

  def request(vals = {})
    prepare = @provider.prepare_payment_submission("http://localhost", 10)
    response = provider_request(prepare, vals)
    query = Rack::Utils.parse_nested_query(response["QUERY_STRING"])
    @provider.confirm_payment_submission(query["token"])
  end

  it "should successfully submit details" do
    result = request
    expect(result.successful?).to eq(true)
  end

  it "should validate name" do
    result = request(:name => '')
    errors = result.errors_for_field(:credit_card, :name).map(&:error_type)

    expect(errors.include?(:blank)).to eq(true)
  end

  it "should validate card number" do
    result = request(:number => 4111)

    expect(result.failure?).to eq(true)
    expect(result.errors_for(:credit_card).empty?).to eq(false)
    expect(result.errors_for(:credit_card)[:number].empty?).to eq(false)
  end

  it "should require card number" do
    result = request(:number => "")
    errors = result.errors_for_field(:credit_card, :number).map(&:error_type)

    expect(errors.include?(:blank)).to eq(true)
  end

  it "should validate expiry month" do
    result = request(:expiration_month => 40)
    errors = result.errors_for_field(:credit_card, :expiration_month).map(&:error_type)

    expect(errors.include?(:invalid)).to eq(true)
  end

  it "should handle month expiration" do
    now = Time.now
    month, year = if now.month - 1 == 0
      [12, now.year - 1]
    else
      [now.month - 1, now.year]
    end

    result = request(:expiration_month => month, :expiration_year => year)
    errors = result.errors_for_field(:credit_card, :expiration_year).map(&:error_type)

    expect(errors.include?(:expired)).to eq(true)
  end

  it "should require expiry month" do
    result = request(:expiration_month => '')
    errors = result.errors_for_field(:credit_card, :expiration_month).map(&:error_type)

    expect(errors.include?(:blank)).to eq(true)
  end

  it "should validate expiry year" do
    result = request(:expiration_year => 2290)
    errors = result.errors_for_field(:credit_card, :expiration_year).map(&:error_type)

    expect(errors.include?(:invalid)).to eq(true)
  end

  it "should handle year expiration" do
    result = request(:expiration_year => 2012)
    errors = result.errors_for_field(:credit_card, :expiration_year).map(&:error_type)

    expect(errors.include?(:expired)).to eq(true)
  end

  it "should validate cvv" do
    result = request(:cvv => "")
    errors = result.errors_for_field(:credit_card, :cvv).map(&:error_type)

    expect(errors.include?(:invalid)).to eq(true)
  end
end
