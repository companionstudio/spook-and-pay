require 'spec_helper'

describe "Braintree submission" do
  before(:all) do
    @provider = SpookAndPay::Providers::Braintree.new(
      :development,
      :merchant_id  => ENV["BRAINTREE_MERCHANT_ID"],
      :public_key   => ENV["BRAINTREE_PUBLIC_KEY"],
      :private_key  => ENV["BRAINTREE_PRIVATE_KEY"]
    )
  end

  describe "of transactions" do
    def request(type, vals = {})
      prepare = @provider.prepare_payment_submission(
        type,
        :type => 'sale', 
        :amount => 10,
        :redirect_url => "http://localhost"
      )

      response = provider_request(prepare, vals)
      @provider.confirm_payment_submission(response["QUERY_STRING"])
    end

    it "should accept an authorize transaction" do
      result = request(:authorize)
      expect(result.successful?).to eq(true)
      expect(result.transaction.status).to eq(:authorized)
    end

    it "should accept purchase transaction" do
      result = request(:purchase)
      expect(result.successful?).to eq(true)
    end

    it "should validate card number" do
      result = request(:purchase, :number => 4111)

      expect(result.failure?).to eq(true)
      expect(result.errors_for(:credit_card).empty?).to eq(false)
      expect(result.errors_for(:credit_card)[:number].empty?).to eq(false)
    end

    it "should validate expiry month" do
      result = request(:purchase, :expiration_month => 40)

      expect(result.failure?).to eq(true)
      expect(result.errors_for(:credit_card).empty?).to eq(false)
      expect(result.errors_for(:credit_card)[:expiration_month].empty?).to eq(false)
    end

    it "should validate expiry year" do
      result = request(:purchase, :expiration_year => "")

      expect(result.failure?).to eq(true)
      expect(result.errors_for(:credit_card).empty?).to eq(false)
      expect(result.errors_for(:credit_card)[:expiration_year].empty?).to eq(false)
    end

    it "should validate cvv" do
      result = request(:purchase, :cvv => 1)

      expect(result.failure?).to eq(true)
      expect(result.errors_for(:credit_card).empty?).to eq(false)
      expect(result.errors_for(:credit_card)[:cvv].empty?).to eq(false)
    end
  end

  describe "of payment details" do

  end
end
