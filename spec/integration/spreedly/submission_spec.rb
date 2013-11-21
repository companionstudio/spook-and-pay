require 'spec_helper'

describe "Spreedly submission" do
  include SpreedlyHelpers

  it "should successfully submit details" do
    result = submission_request(:store)
    expect(result.successful?).to eq(true)
  end

  it "should validate name" do
    result = submission_request(:store, :name => '')
    errors = result.errors_for_field(:credit_card, :name).map(&:error_type)

    expect(errors.include?(:blank)).to eq(true)
  end

  it "should validate card number" do
    result = submission_request(:store, :number => 4111)

    expect(result.failure?).to eq(true)
    expect(result.errors_for(:credit_card).empty?).to eq(false)
    expect(result.errors_for(:credit_card)[:number].empty?).to eq(false)
  end

  it "should require card number" do
    result = submission_request(:store, :number => "")
    errors = result.errors_for_field(:credit_card, :number).map(&:error_type)

    expect(errors.include?(:blank)).to eq(true)
  end

  it "should validate expiry month" do
    result = submission_request(:store, :expiration_month => 40)
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

    result = submission_request(:store, :expiration_month => month, :expiration_year => year)
    errors = result.errors_for_field(:credit_card, :expiration_year).map(&:error_type)

    expect(errors.include?(:expired)).to eq(true)
  end

  it "should require expiry month" do
    result = submission_request(:store, :expiration_month => '')
    errors = result.errors_for_field(:credit_card, :expiration_month).map(&:error_type)

    expect(errors.include?(:blank)).to eq(true)
  end

  it "should validate expiry year" do
    result = submission_request(:store, :expiration_year => 2290)
    errors = result.errors_for_field(:credit_card, :expiration_year).map(&:error_type)

    expect(errors.include?(:invalid)).to eq(true)
  end

  it "should handle year expiration" do
    result = submission_request(:store, :expiration_year => 2012)
    errors = result.errors_for_field(:credit_card, :expiration_year).map(&:error_type)

    expect(errors.include?(:expired)).to eq(true)
  end

  it "should validate cvv" do
    result = submission_request(:store, :cvv => "")
    errors = result.errors_for_field(:credit_card, :cvv).map(&:error_type)

    expect(errors.include?(:invalid)).to eq(true)
  end
end
