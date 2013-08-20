module SpookAndPay
  # A simple, generic class which wraps the card details retrieved from a
  # provider. This class is entirely read only, since it is only used to
  # as part of inspecting a payment or handling errors.
  class CreditCard
    # The basic attributes of the credit card.
    attr_reader :provider, :id, :valid, :expired

    # The fields required for a credit card
    FIELDS = [:number, :expiration_month, :expiration_year, :cvv, :card_type, :name].freeze

    # Define readers for all the fields
    attr_reader *FIELDS

    # Construct a new credit card using the ID from the provider and a hash
    # containing the values of the card.
    #
    # @param SpookAndPay::Providers::Base provider
    # @param [Numeric, String] id
    # @param [true, false] valid
    # @param [true, false] expired
    # @param Hash vals
    #
    # @return nil
    def initialize(provider, id, valid, expired, vals)
      @provider = provider
      @id       = id
      @valid    = valid
      @expired  = expired

      FIELDS.each do |field|
        if vals.has_key?(field)
          instance_variable_set(:"@#{field}", vals[field]) 
        end
      end

      nil
    end

    # Authorizes a payment of the specified amount. This generates a new
    # transaction that must be later settled.
    #
    # @param [String, Numeric] amount
    # @return SpookAndPay::Result
    def authorize!(amount)
      provider.authorize_via_credit_card(self, amount)
    end

    # Generates a payment of the specified amount.
    #
    # @param [String, Numeric] amount
    # @return SpookAndPay::Result
    def purchase!(amount)
      provider.purchase_via_credit_card(self, amount)
    end

    # Deletes the credit card from the provider's vault.
    #
    # @return [true, false]
    def delete!
      provider.delete_credit_card(self)
    end

    # Indicates if the card details are valid.
    #
    # @return [true, false]
    def valid?
      @valid
    end

    # Indicates if the card is expired. This is not calculated, but instead
    # determined by the provider.
    #
    # @return [true, false]
    def expired?
      @expired
    end
  end
end
