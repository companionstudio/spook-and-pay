require 'spec_helper'

describe SpookAndPay::CreditCard do
  FIELDS = {
    :number           => "4111111111111111",
    :expiration_month => 4,
    :expiration_year  => 2020,
    :cvv              => 123,
    :card_type        => 'visa',
    :name             => "Doctor Crumpet",
    :valid            => true,
    :expired          => false
  }.freeze

  def credit_card(provider, vals = {})
    SpookAndPay::CreditCard.new(provider, 'derp', FIELDS.merge(vals))
  end

  describe "basic predicates" do
    before(:each) do
      @supporting = double("supporting")
    end

    it "should be valid" do
      expect(credit_card(@supporting).valid?).to eq(true)
    end

    it "should not be valid" do
      expect(credit_card(@supporting, :valid => false).valid?).to eq(false)
    end

    it "should be expired" do 
      expect(credit_card(@supporting, :expired => true).expired?).to eq(true)
    end

    it "should not be expired" do
      expect(credit_card(@supporting).expired?).to eq(false)
    end
  end

  describe "with provider support" do
    before(:each) do
      @supporting = double("supporting").tap do |p|
        p.stub(:supports_credit?).and_return(true)
        p.stub(:supports_authorize?).and_return(true)
        p.stub(:supports_purchase?).and_return(true)
        p.stub(:supports_delete?).and_return(true)
        p.stub(:credit_via_credit_card).and_return(true)
        p.stub(:authorize_via_credit_card).and_return(true)
        p.stub(:purchase_via_credit_card).and_return(true)
        p.stub(:delete_credit_card).and_return(true)
      end

      @valid_card = credit_card(@supporting)
      @invalid_card = credit_card(@supporting, :expired => true)
    end

    describe "predicates" do
      it "should indicate it can credit" do
        expect(@valid_card.can_credit?).to eq(true)
      end

      it "should indicate it cannot credit" do
        expect(@invalid_card.can_credit?).to eq(false)
      end

      it "should indicate it can authorize" do
        expect(@valid_card.can_authorize?).to eq(true)
      end

      it "should indicate it cannot authorize" do
        expect(@invalid_card.can_authorize?).to eq(false)
      end

      it "should indicate it can purchase" do
        expect(@valid_card.can_purchase?).to eq(true)
      end

      it "should indicate it cannot purchase" do 
        expect(@invalid_card.can_purchase?).to eq(false)
      end

      it "should indicate it can be deleted" do
        expect(@valid_card.can_delete?).to eq(true)
      end
    end

    describe "actions" do
      it "should credit" do
        expect(@valid_card.credit!(20)).to eq(true)
      end

      it "should raise error when attempting credit" do
        expect{@invalid_card.credit!(20)}.to raise_error(SpookAndPay::CreditCard::InvalidCardError)
      end

      it "should authorize" do
        expect(@valid_card.credit!(20)).to eq(true)
      end

      it "should raise error when attempting authorize" do
        expect{@invalid_card.authorize!(20)}.to raise_error(SpookAndPay::CreditCard::InvalidCardError)
      end

      it "should make a purchase" do
        expect(@valid_card.purchase!(20)).to eq(true)
      end

      it "should raise error when attempting purchase" do
        expect{@invalid_card.purchase!(20)}.to raise_error(SpookAndPay::CreditCard::InvalidCardError)
      end

      it "should delete" do
        expect(@valid_card.delete!).to eq(true)
      end
    end
  end

  describe "without provider support" do
    before(:each) do
      provider = double("non-supporting").tap do |p|
        p.stub(:supports_credit?).and_return(false)
        p.stub(:supports_authorize?).and_return(false)
        p.stub(:supports_purchase?).and_return(false)
        p.stub(:supports_delete?).and_return(false)
        p.stub(:credit_via_credit_card).and_raise(SpookAndPay::Providers::Base::NotSupportedError)
        p.stub(:authorize_via_credit_card).and_raise(SpookAndPay::Providers::Base::NotSupportedError)
        p.stub(:purchase_via_credit_card).and_raise(SpookAndPay::Providers::Base::NotSupportedError)
        p.stub(:delete_credit_card).and_raise(SpookAndPay::Providers::Base::NotSupportedError)
      end

      @credit_card = credit_card(provider)
    end

    describe "predicates" do
      it "should indicate it cannot credit" do
        expect(@credit_card.can_credit?).to eq(false)
      end

      it "should indicate it cannot authorize" do
        expect(@credit_card.can_authorize?).to eq(false)
      end

      it "should indicate it cannot purchase" do
        expect(@credit_card.can_purchase?).to eq(false)
      end

      it "should indicate it cannot be deleted" do
        expect(@credit_card.can_delete?).to eq(false)
      end
    end

    describe "actions" do
      it "should raise an error when attempting credit" do
        expect {@credit_card.credit!(20)}.to raise_error(SpookAndPay::Providers::Base::NotSupportedError)
      end

      it "should raise an error when attempting authorization" do
        expect {@credit_card.authorize!(20)}.to raise_error(SpookAndPay::Providers::Base::NotSupportedError)
      end

      it "should raise an error when attempting a purchase" do
        expect {@credit_card.purchase!(20)}.to raise_error(SpookAndPay::Providers::Base::NotSupportedError)
      end

      it "should raise an error when attempting to delete" do
        expect {@credit_card.delete!}.to raise_error(SpookAndPay::Providers::Base::NotSupportedError)
      end
    end
  end
end
