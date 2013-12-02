module SpreedlyHelpers
  include RequestHelpers

  # Returns a Spreedly provider instance configured using global vars.
  #
  # @return SpookAndPay::Providers::Spreedly
  def provider
    @provider ||= SpookAndPay::Providers::Spreedly.new(
      :development,
      :environment_key => ENV["SPREEDLY_ENVIRONMENT_KEY"],
      :access_secret   => ENV["SPREEDLY_ACCESS_SECRET"],
      :gateway_token   => ENV["SPREEDLY_GATEWAY_TOKEN"],
      :currency_code   => ENV["SPREEDLY_CURRENCY_CODE"]
    )
  end

  # Makes a request to Spreedly's transparent redirect end-point.
  #
  # @param Hash vals
  # @return SpookAndPay::Result
  def submission_request(type, vals = {})
    amount = vals.delete(:amount)
    prepare = provider.prepare_payment_submission("http://localhost", 10)
    response = provider_request(prepare, vals)
    provider.confirm_payment_submission(response["QUERY_STRING"], :execute => type, :amount => amount)
  end

  # Generates a payment method by submitting to Spreedly's transparent redirect
  # and returns the credit card instance.
  #
  # @return SpookAndPay::CreditCard
  def credit_card
    submission_request(:store).credit_card
  end
end
