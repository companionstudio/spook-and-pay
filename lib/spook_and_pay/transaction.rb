module SpookAndPay
  # A simple class representing an interaction with a provider. Each 
  # interaction has an ID, a type and may be successful or not. It is 
  # read-only.
  class Transaction
    # Basic attributes
    attr_reader :provider, :id, :type, :payload, :created_at, :status

    # The basic types for transactions.
    TYPES = [:purchase, :authorize, :capture, :credit, :void].freeze

    # @param SpookAndPay::Providers::Base provider
    # @todo Check type against the TYPES collection.
    def initialize(provider, id, type, created_at, status, payload = {})
      @provider   = provider
      @id         = id
      @type       = type
      @created_at = created_at
      @payload    = payload
    end

    # Refunds the transaction. The related credit card will be credited for
    # the amount captured. It will only succeed for purchases or captured
    # authorizations.
    #
    # @return SpookAndPay::Result
    def refund!
      provider.refund_transaction(self)
    end

    def capture!
      provider.capture_transaction(self)
    end

    def void!
      provider.void_transaction(self)
    end
  end
end
