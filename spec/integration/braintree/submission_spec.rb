require 'spec_helper'

describe "Braintree submission" do
  include BraintreeHelpers

  it "should accept an authorize transaction" do
    result = submission_request(:authorize)
    expect(result.successful?).to eq(true)
    expect(result.transaction.status).to eq(:authorized)
  end

  it "should accept purchase transaction" do
    result = submission_request(:purchase)
    expect(result.successful?).to eq(true)
  end

  it "should validate card number" do
    result = submission_request(:purchase, :number => 4111)

    expect(result.failure?).to eq(true)
    expect(result.errors_for(:credit_card).empty?).to eq(false)
    expect(result.errors_for(:credit_card)[:number].empty?).to eq(false)
  end

  it "should validate expiry month" do
    result = submission_request(:purchase, :expiration_month => 40)

    expect(result.failure?).to eq(true)
    expect(result.errors_for(:credit_card).empty?).to eq(false)
    expect(result.errors_for(:credit_card)[:expiration_month].empty?).to eq(false)
  end

  it "should validate expiry year" do
    result = submission_request(:purchase, :expiration_year => "")

    expect(result.failure?).to eq(true)
    expect(result.errors_for(:credit_card).empty?).to eq(false)
    expect(result.errors_for(:credit_card)[:expiration_year].empty?).to eq(false)
  end

  it "should validate cvv" do
    result = submission_request(:purchase, :cvv => 1)

    expect(result.failure?).to eq(true)
    expect(result.errors_for(:credit_card).empty?).to eq(false)
    expect(result.errors_for(:credit_card)[:cvv].empty?).to eq(false)
  end
end
