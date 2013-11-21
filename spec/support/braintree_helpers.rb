module BraintreeHelpers
  include RequestHelpers

  # Returns a provider instance configured using global vars.
  #
  # @return SpookAndPay::Providers::Braintree
  def provider
    @provider ||= SpookAndPay::Providers::Braintree.new(
      :development,
      :merchant_id  => ENV["BRAINTREE_MERCHANT_ID"],
      :public_key   => ENV["BRAINTREE_PUBLIC_KEY"],
      :private_key  => ENV["BRAINTREE_PRIVATE_KEY"]
    )
  end

  # Submits details to Braintree's transparent redirect end-point.
  #
  # @param [:purchase, :authorize, :store]
  # @param Hash vals
  # @return SpookAndPay::Result
  def submission_request(type, vals = {})
    prepare = provider.prepare_payment_submission("http://localhost", :amount => 10, :type => type)
    response = provider_request(prepare, vals)
    provider.confirm_payment_submission(response["QUERY_STRING"])
  end
end
