require 'spec_helper'

describe "Spreedly credit cards" do
  include SpreedlyHelpers

  it "should authorize funds" do
    result = credit_card.authorize!(100)
    expect(result.successful?).to eq(true)
  end

  it "should make a purchase" do
    result = credit_card.purchase!(100)
    expect(result.successful?).to eq(true)
  end
end
