module SpookAndPay
  module Providers
    class Spreedly < Base
      # The map of generic field names to what is specifically required by
      # Spreedly.
      FORM_FIELD_NAMES = {
        :name             => "credit_card[full_name]",
        :number           => "credit_card[number]",
        :expiration_month => "credit_card[month]",
        :expiration_year  => "credit_card[year]",
        :cvv              => "credit_card[verification_value]"
      }.freeze

      # The which refers to a specific gateway. 
      #
      # @attr_reader String
      attr_reader :gateway_token

      # An instance of the spreedly spreedly.
      #
      # @attr_reader Spreedly::Environment
      attr_reader :spreedly

      # Generate a new instance of the Spreedly provider.
      #
      # @param Hash config
      # @option config String :environment_key
      # @option config String :access_secret
      # @option config String :gateway_token
      def initialize(env, config)
        @gateway_token = config[:gateway_token]
        @spreedly = ::Spreedly::Environment.new(config[:environment_key], config[:access_secret])

        super(env, config)
      end

      def prepare_payment_submission(redirect_url, opts = {})
        {
          :url            => spreedly.transparent_redirect_form_action,
          :field_names    => self.class::FORM_FIELD_NAMES,
          :hidden_fields  => {:redirect_url => redirect_url, :environment_key => spreedly.key}
        }
      end

      # Confirms the submission of payment details to Spreedly Core.
      #
      # @param String token
      # @return SpookAndPay::Result
      def confirm_payment_submission(token)
        credit_card = spreedly.find_payment_method(token)

        if credit_card.valid?
          SpookAndPay::Result.new(
            true, 
            credit_card, 
            :credit_card => coerce_credit_card(credit_card)
          )
        else
          SpookAndPay::Result.new(
            false, 
            credit_card, 
            :credit_card => coerce_credit_card(credit_card),
            :errors => extract_card_errors(credit_card)
          )
        end
      end

      def credit_card(id)
        result = spreedly.find_payment_method(id)
        coerce_credit_card(result)
      end

      def credit_card_from_transaction(id)
        result = spreedly.find_transaction(id)
        coerce_credit_card(result.payment_method)
      end

      def transaction(id)
        result = spreedly.find_transaction(id)
        coerce_transaction(result)
      end

      def capture_transaction(id)
        result = spreedly.capture_transaction(id) 
        coerce_result(result)
      end

      def refund_transaction(id)
        result = spreedly.refund_transaction(id)
        coerce_result(result)
      end

      def void_transaction(id)
        result = spreedly.void_transaction(id)
        coerce_result(result)
      end

      def authorize_via_credit_card(id, amount)
        result = spreedly.authorize_on_gateway(gateway_token, credit_card_id(id), amount.to_f * 100)
        coerce_result(result)
      end

      def purchase_via_credit_card(id, amount)
        result = spreedly.purchase_on_gateway(gateway_token, credit_card_id(id), amount.to_f * 100)
        coerce_result(result)
      end

      def delete_credit_card(id)
        result = spreedly.redact_payment_method(id)
        coerce_result(result)
      end

      private

      # Takes the result of running a transaction against a Spreedly gateway
      # and coerces it into a SpookAndPay::Result
      #
      # @param Spreedly::Transaction result
      # @return SpookAndPay::Result
      def coerce_result(result)
        opts = {
          :transaction  => coerce_transaction(result),
          :card         => coerce_credit_card(result.payment_method),
          :errors       => extract_transaction_errors(result)
        }

        SpookAndPay::Result.new(result.succeeded, result, opts)
      end

      # A mapping from the names used by Spreedly to the names SpookAndPay uses
      # internally.
      CARD_FIELDS = {
        "full_name" => :name, 
        "number" => :number,
        "year" => :expiration_year,
        "month" => :expiration_month,
        "verification_value" => :cvv
      }.freeze

      # Maps the error types from Spreedly's to the names used internally.
      ERRORS = {
        "errors.invalid" => :invalid,
        "errors.blank" => :blank,
        "errors.expired" => :expired
      }.freeze

      # Extracts/coerces errors from a Spreedly response into SubmissionError
      # instances.
      #
      # @param Spreedly::CreditCard result
      # @return Array<SpookAndPay::SubmissionError>
      # @todo If the Spreedly API behaves later, the check for first/last 
      #       name might not be needed anymore.
      def extract_card_errors(result)
        # This gnarly bit of code transforms errors on the first_name or 
        # last_name attributes into an error on full_name. This is because
        # Spreedly accepts input for full_name, but propogates errors to the 
        # separate attributes.
        errors = result.errors.map do |e|
          case e[:attribute]
          when 'first_name' then e.merge(:attribute => "full_name")
          when 'last_name' then nil
          else e
          end
        end.compact

        errors.map do |e|
          name = CARD_FIELDS[e[:attribute]]
          error = ERRORS[e[:key]]

          if name and error
            SubmissionError.new(:credit_card, error, name, e)
          else
            SubmissionError.new(:unknown, :unknown, :unknown, e)
          end
        end
      end

      # Extracts/coerces errors from a Spreedly transaction into 
      # SubmissionError instances.
      #
      # @param Spreedly::Transaction result
      # @return Array<SpookAndPay::SubmissionError>
      def extract_transaction_errors(result)
        []
      end

      # Takes the response generated by the Spreedly lib and coerces it into a
      # SpookAndPay::CreditCard
      #
      # @param Spreedly::CreditCard
      # @return SpookAndPay::CreditCard
      def coerce_credit_card(card)
        fields = {
          :card_type        => card.card_type,
          :number           => card.number,
          :name             => card.full_name,
          :expiration_month => card.month,
          :expiration_year  => card.year
        }

        SpookAndPay::CreditCard.new(self, card.token, fields)
      end

      # Takes a transaction generated by the Spreedly lib and coerces it into a
      # SpookAndPay::Transaction
      #
      # @param Spreedly::Transaction transaction
      # @return SpookAndPay::Transaction
      # @todo extract created_at and status from the transaction.response
      def coerce_transaction(transaction)
        fields = {}

        fields[:type] = case transaction
        when ::Spreedly::Authorization then :authorize
        when ::Spreedly::Purchase then :purchase
        when ::Spreedly::Capture then :capture
        when ::Spreedly::Refund then :credit
        when ::Spreedly::Void then :void
        end

        if transaction.respond_to?(:amount)
          fields[:amount] = transaction.amount
        end

        SpookAndPay::Transaction.new(self, transaction.token, nil, transaction, fields)
      end
    end
  end
end
