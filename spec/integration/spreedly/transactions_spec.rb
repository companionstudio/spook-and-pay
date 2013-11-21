require 'spec_helper'

describe "Spreedly transactions" do
  include SpreedlyHelpers

  it "should capture authorized funds" do
    auth = credit_card.authorize!(2500)
    capture = auth.transaction.capture!
    expect(capture.successful?).to eq(true)
  end

  it "should refund" do
    purchase = credit_card.purchase!(2500)
    expect(purchase.successful?).to eq(true)
    refund = purchase.transaction.refund!
    expect(refund.successful?).to eq(true)
  end

  it "should void" do
    auth = credit_card.authorize!(2500)
    void = auth.transaction.void!
    expect(void.successful?).to eq(true)
  end
end
