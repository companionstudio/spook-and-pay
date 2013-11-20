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
      :gateway_token   => ENV["SPREEDLY_GATEWAY_TOKEN"]
    )
  end

  # Makes a request to Spreedly's transparent redirect end-point.
  #
  # @param Hash vals
  # @return SpookAndPay::Result
  def submission_request(vals = {})
    prepare = provider.prepare_payment_submission("http://localhost", 10)
    response = provider_request(prepare, vals)
    query = Rack::Utils.parse_nested_query(response["QUERY_STRING"])
    provider.confirm_payment_submission(query["token"])
  end

  # Generates a payment method by submitting to Spreedly's transparent redirect
  # and returns the credit card instance.
  #
  # @return SpookAndPay::CreditCard
  def credit_card
    submission_request.credit_card
  end
end
