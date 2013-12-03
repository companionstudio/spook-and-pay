module SpookAndPay
  # A simple, generic class which wraps the card details retrieved from a
  # provider. This class is entirely read only, since it is only used to
  # as part of inspecting a payment or handling errors.
  class CreditCard
    # This module adds the ::attr_erroring_reader to this class
    extend SpookAndPay::ErroringReader

    # An error raised when trying to perform an action on a card that has 
    # invalid details or has expired.
    class InvalidCardError < StandardError
      def to_s
        "The action cannot be performed, this card is invalid or expired."
      end
    end

    # The basic attributes of the credit card.
    attr_reader :provider, :id, :raw

    # The fields required for a credit card
    FIELDS = [:number, :expiration_month, :expiration_year, :cvv, :card_type, :name, :valid, :expired].freeze

    # Define readers for all the fields
    attr_reader *FIELDS

    # Define a subset of the readers as erroring
    attr_erroring_reader :valid, :expired

    # Construct a new credit card using the ID from the provider and a hash
    # containing the values of the card.
    #
    # @param SpookAndPay::Providers::Base provider
    # @param [Numeric, String] id
    # @param Hash vals
    # @option vals String :number
    # @option vals [String, Numeric] :expiration_month
    # @option vals [String, Numeric] :expiration_year
    # @option vals [String, Numeric] :cvv
    # @option vals String :card_type
    # @option vals String :name
    # @option vals [true, false] :expired
    # @option vals [true, false] :valid
    # @param Class raw
    def initialize(provider, id, vals, raw = nil)
      @provider = provider
      @id       = id
      @raw      = raw
      FIELDS.each {|f| instance_variable_set(:"@#{f}", vals[f]) if vals.has_key?(f)}
    end

    # A getter which takes the card number stored and generates a nice masked 
    # version. It also handles the case where the number isn't available and 
    # just returns nil instead.
    #
    # @return String
    def number
      if @number.nil? or @number.empty?
        nil
      else
        if @number.length < 12
          case card_type
          when 'american_express' then "XXXX-XXXXXX-#{@number}"
          else "XXXX-XXXX-XXXX-#{@number}"
          end
        else
          @number
        end
      end
    end

    # Checks to see if funds can be credited to a card. Depends on the 
    # gateway/provider supporting crediting and having a valid card.
    #
    # @return [true, false]
    def can_credit?
      provider.supports_credit? and valid? and !expired?
    end

    # Checks to see if this card can be authorized against the specified
    # gateway.
    #
    # @return [true, false]
    def can_authorize?
      provider.supports_authorize? and valid? and !expired?
    end

    # Checks to see if this card can be used for a purchase against the 
    # underlying gateway.
    #
    # @return [true, false]
    def can_purchase?
      provider.supports_purchase? and valid? and !expired?
    end

    # Checks to see if the provider/gateway supports the deletion of credit
    # card details.
    #
    # @return [true, false]
    def can_delete?
      provider.supports_delete?
    end

    # Credits the specified amount to the card.
    #
    # @param [String, Numeric] amount
    # @return SpookAndPay::Result
    # @raises SpookAndPay::Providers::Base::NotSupportedError
    # @raises SpookAndPay::CreditCard::InvalidCardError
    def credit!(amount)
      verify_action
      provider.credit_via_credit_card(self, amount)
    end

    # Authorizes a payment of the specified amount. This generates a new
    # transaction that must be later settled.
    #
    # @param [String, Numeric] amount
    # @return SpookAndPay::Result
    # @raises SpookAndPay::Providers::Base::NotSupportedError
    # @raises SpookAndPay::CreditCard::InvalidCardError
    def authorize!(amount)
      verify_action
      provider.authorize_via_credit_card(self, amount)
    end

    # Generates a payment of the specified amount.
    #
    # @param [String, Numeric] amount
    # @return SpookAndPay::Result
    # @raises SpookAndPay::Providers::Base::NotSupportedError
    # @raises SpookAndPay::CreditCard::InvalidCardError
    def purchase!(amount)
      verify_action
      provider.purchase_via_credit_card(self, amount)
    end

    # Deletes the credit card from the provider's vault.
    #
    # @return SpookAndPay::Result
    # @raises SpookAndPay::Providers::Base::NotSupportedError
    def delete!
      provider.delete_credit_card(self)
    end

    # Indicates if the card details are valid.
    #
    # @return [true, false]
    def valid?
      valid
    end

    # Indicates if the card is expired. This is not calculated, but instead
    # determined by the provider.
    #
    # @return [true, false]
    def expired?
      expired
    end

    private


    # A helper method which validates any actions — authorize, credit etc. —
    # and where the card is expired or has invalid details, raises an error.
    #
    # @return nil
    # @raises SpookAndPay::CreditCard::InvalidCardError
    def verify_action
      raise InvalidCardError if expired? or !valid?
    end
  end
end
