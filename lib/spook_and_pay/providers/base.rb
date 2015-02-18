module SpookAndPay
  module Providers
    # The abstract class from which other Provider classes should inherit. This
    # class is intended to behave more as a template than anything else. It
    # provides very little in the way of actual implementation.
    #
    # To implement a provider all of the public methods of this class —
    # excluding #initialize — must be implemented.
    #
    # Some features may not be supported by a provider, in which case the
    # `NotSupportedError` should be raised in lieu of a real implementation.
    class Base
      # A hash which maps between the fields for a credit card and the actual
      # form field names required by the provider.
      #
      # It should be over-ridden per provider.
      FORM_FIELD_NAMES = {}.freeze

      # An error used when validating the contents of an options hash. Since
      # many of the methods on the provider classes take additional arguments
      # as a Hash, it's important to make sure we give good errors when they
      # are missing.
      class InvalidOptionsError < StandardError
        def initialize(errors)
          @errors = errors
        end

        def to_s
          "You have missed, or provided invalid options"
        end
      end

      # An error for indicating actions that are not supported by a particular
      # provider. In general, it will be the Base subclasses that define thier
      # own versions of the the method that throw this error.
      class NotSupportedError < StandardError
        def to_s
          "This action is not supported by this provider."
        end
      end

      # Basic attributes
      attr_reader :environment, :config

      # @param [:production, :development, :test] env
      # @param Hash config
      #
      # @return nil
      def initialize(env, config)
        @environment = env
        @config = config

        nil
      end

      # Retrieves the payment method details from the provider's vault.
      #
      # @param String id
      #
      # @return [SpookAndPay::CreditCard, nil]
      def credit_card(id)
        raise NotImplementedError
      end

      # Retrieves a credit card from the provider based on the transaction
      # or transaction id provided. Some providers may not support this action.
      #
      # @param [String, SpookAndPay::Transaction] transaction_or_id
      # @return [SpookAndPay::CreditCard, nil]
      def credit_card_from_transaction(transaction_or_id)
        raise NotSupportedError
      end

      # Retrieves the transaction details from the provider's vault.
      #
      # @param String id
      #
      # @return [SpookAndPay::Transaction, nil]
      def transaction(id)
        raise NotImplementedError
      end

      # Returns a hash containing the details necessary for making a
      # submission. If you know what you're doing, you can use this directly,
      # but otherwise you should be using the form helpers.
      #
      # The details generated by this method are for submitting card details to
      # the provider for storage. Billing etc has to be handled via a separate
      # step after submission.
      #
      # The arguments for this are specific to each provider implementation,
      # but they all return a Hash with the same keys, like so:
      #   {
      #     :url => "...",
      #     :hidden_fields => {...},
      #     :field_names => {...}
      #   }
      #
      # Where :url is the target URL, :hidden_fields should be embedded in a
      # form as they are and :field_names provide the mapping between known
      # keys like :number and :cvv to the input names required by the provider.
      def prepare_payment_submission(*args)
        raise NotImplementedError
      end

      # Confirms the submission of payment details to the provider.
      #
      # The arguments for this method are specific to a provider.
      def confirm_payment_submission(*args)
        raise NotImplementedError
      end

      # Captures funds that have been pre-authorized.
      #
      # This should not be called directly. Instead, use the #capture! method
      # provided by a Transaction instance.
      #
      # @param [SpookAndPay::Transaction, String] id
      # @return SpookAndPay::Result
      def capture_transaction(id)
        check_support('capture')
      end

      # Refunds the amount of money captured in a transaction.
      #
      # This should not be called directly. Instead, use the #refund! method
      # provided by a Transaction instance.
      #
      # @param [SpookAndPay::Transaction, String] id
      # @return SpookAndPay::Result
      def refund_transaction(id)
        check_support('refund')
      end

      # Partially refunds the amount of money captured in a transaction.
      #
      # This should not be called directly. Instead, use the #partial_refund! method
      # provided by a Transaction instance.
      #
      # @param [SpookAndPay::Transaction, String] id
      # @return SpookAndPay::Result
      def partially_refund_transaction(id)
        check_support('partial_refund')
      end

      # Checks to see if purchasing is supported. This is dependent on the payment
      # provider. The default implementation simply returns true. Specific
      # implementations should over-ride this method.
      #
      # @return [true, false]
      def supports_purchase?
        true
      end

      # Checks to see if voiding is supported. This is dependent on the payment
      # provider. The default implementation simply returns true. Specific
      # implementations should over-ride this method.
      #
      # @return [true, false]
      def supports_void?
        true
      end

      # Checks to see if crediting is supported. This is dependent on the payment
      # provider. The default implementation simply returns true. Specific
      # implementations should over-ride this method.
      #
      # @return [true, false]
      def supports_credit?
        true
      end

      # Checks to see if refunding is supported. This is dependent on the payment
      # provider. The default implementation simply returns true. Specific
      # implementations should over-ride this method.
      #
      # @return [true, false]
      def supports_refund?
        true
      end

      # Checks to see if partial refunding is supported. This is dependent on
      # the payment provider. The default implementation simply returns true.
      # Specific implementations should over-ride this method.
      #
      # @return [true, false]
      def supports_partial_refund?
        true
      end

      # Checks to see if capturing is supported. This is dependent on the payment
      # provider. The default implementation simply returns true. Specific
      # implementations should over-ride this method.
      #
      # @return [true, false]
      def supports_capture?
        true
      end

      # Checks to see if authorizing is supported. This is dependent on the payment
      # provider. The default implementation simply returns true. Specific
      # implementations should over-ride this method.
      #
      # @return [true, false]
      def supports_authorize?
        true
      end

      # Checks to see if the deletion of payment details is supported. This is
      # dependent on the payment provider. The default implementation simply
      # returns true. Specific implementations should over-ride this method.
      #
      # @return [true, false]
      def supports_delete?
        true
      end

      # Voids an authorization.
      #
      # This should not be called directly. Instead, use the #void! method
      # provided by a Transaction instance.
      #
      # @param [SpookAndPay::Transaction, String] id
      # @return SpookAndPay::Result
      # @api private
      # @abstract Subclass to implement
      def void_transaction(id)
        check_support('void')
      end

      # Authorizes a payment against a credit card
      #
      # This should not be called directly. Instead, use the #authorize! method
      # provided by a CreditCard instance.
      #
      # @param [SpookAndPay::CreditCard, String] id
      # @param [String, Numeric] amount in dollars
      # @return SpookAndPay::Result
      # @api private
      # @abstract Subclass to implement
      def authorize_via_credit_card(id, amount)
        check_support('authorize')
      end

      # Credits funds to a credit card
      #
      # This should not be called directly. Instead, use the #authorize! method
      # provided by a CreditCard instance.
      #
      # @param [SpookAndPay::CreditCard, String] id
      # @param [String, Numeric] amount in dollars
      # @return SpookAndPay::Result
      # @api private
      # @abstract Subclass to implement
      def credit_via_credit_card(id, amount)
        check_support('credit')
      end

      # Creates a purchase against a credit card.
      #
      # This should not be called directly. Instead, use the #purchase! method
      # provided by a CreditCard instance.
      #
      # @param [SpookAndPay::CreditCard, String] id
      # @param [String, Numeric] amount
      # @return SpookAndPay::Result
      # @api private
      # @abstract Subclass to implement
      def purchase_via_credit_card(id, amount)
        check_support('purchase')
      end

      # Removes payment details from the provider's vault.
      #
      # This should not be called directly. Instead, use the #delete! method
      # provided by a CreditCard instance.
      #
      # @param [SpookAndPay::CreditCard, String] id
      # @return SpookAndPay::Result
      # @api private
      # @abstract Subclass to implement
      def delete_credit_card(id)
        check_support('delete')
      end

      # Retains a credit card within the provider's vault.
      #
      # This should not be called directly. Instead, use the #retain! method
      # provided by a CreditCard instance.
      #
      # @param [SpookAndPay::CreditCard, String] id
      # @return SpookAndPay::Result
      # @api private
      # @abstract Subclass to implement
      def retain_credit_card(id)
        check_support('retain')
      end

      private

      # Checks to see if a particular action is defined as being supported and
      # raises the appropriate error.
      #
      # The basic semantics is this; if someone implementing a provider says an
      # action is supported via a #supports_*? predicate, this method should
      # never be called, so we raise NotImplementedError. Otherwise they are
      # saying it's not supported and the appropriate response is to raise a
      # NotSupportedError.
      #
      # @param String action
      # @return nil
      # @raises NotSupportedError
      # @raises NotImplementedError
      def check_support(action)
        if send(:"supports_#{action}?")
          raise NotImplementedError
        else
          raise NotSupportedError
        end
      end

      # Extracts the credit card id from it's argument. This is is to help with
      # methods that accept either a card instance of an id.
      #
      # @param [SpookAndPay::CreditCard, String]
      # @return String
      def credit_card_id(id)
        case id
        when SpookAndPay::CreditCard then id.id
        else id
        end
      end

      # Extracts a transaction ID from it's target.
      #
      # @param [SpookAndPay::Transaction, String]
      # @return String
      def transaction_id(id)
        case id
        when SpookAndPay::Transaction then id.id
        else id
        end
      end
    end
  end
end
