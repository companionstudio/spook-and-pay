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

      # Currency code. Spreedly defaults to USD, but we default to AUD.
      #
      # @attr_reader String
      attr_reader :currency_code

      # Generate a new instance of the Spreedly provider.
      #
      # @param Hash config
      # @option config String :environment_key
      # @option config String :access_secret
      # @option config String :gateway_token
      # @option config String :currency_code
      def initialize(env, config)
        @gateway_token = config[:gateway_token]
        @currency_code = config[:currency_code] || 'AUD'
        @spreedly = ::Spreedly::Environment.new(
          config[:environment_key], 
          config[:access_secret],
          :currency_code => currency_code
        )

        super(env, config)
      end

      # @param String redirect_url
      # @param Hash opts
      # @return Hash
      def prepare_payment_submission(redirect_url, opts = {})
        config = {
          :url            => spreedly.transparent_redirect_form_action,
          :field_names    => self.class::FORM_FIELD_NAMES,
          :hidden_fields  => {:redirect_url => redirect_url, :environment_key => spreedly.key}
        }

        if opts[:token]
          config[:hidden_fields][:payment_method_token] = opts[:token]
        end

        config
      end

      # Confirms the submission of payment details to Spreedly Core.
      #
      # @param String query_string
      # @param Hash opts
      # @option opts [String, Numeric] :amount
      # @option opts [:purchase, :authorize, :store] :execute
      # @return SpookAndPay::Result
      def confirm_payment_submission(query_string, opts)
        token = Rack::Utils.parse_nested_query(query_string)["token"]
        card = credit_card(token)

        if card.valid?
          case opts[:execute]
          when :authorize then card.authorize!(opts[:amount])
          when :purchase  then card.purchase!(opts[:amount])
          when :store     then SpookAndPay::Result.new(true, nil, :credit_card => card)
          end
        else
          SpookAndPay::Result.new(false, nil, :credit_card => card, :errors => extract_card_errors(card.raw))
        end
      end

      def credit_card(id)
        result = spreedly.find_payment_method(id)
        coerce_credit_card(result)
      end

      def credit_card_from_transaction(id)
        result = spreedly.find_transaction(transaction_id(id))
        coerce_credit_card(result.payment_method)
      end

      def transaction(id)
        result = spreedly.find_transaction(id)
        coerce_transaction(result)
      end

      def capture_transaction(id)
        result = spreedly.capture_transaction(transaction_id(id))
        coerce_result(result)
      end

      def refund_transaction(id)
        result = spreedly.refund_transaction(transaction_id(id))
        coerce_result(result)
      end

      def void_transaction(id)
        result = spreedly.void_transaction(transaction_id(id))
        coerce_result(result)
      end

      # This is a nasty little trick that makes the spreedly gateway class 
      # store the characteristics XML fragment from the server.
      #
      # @todo In later versions this might not be necessary. When updating the
      # spreedly gem, check it.
      ::Spreedly::Gateway.send(:field, :characteristics)

      def supports_purchase?
        check_support_for('supports_purchase')
      end

      def supports_void?
        check_support_for('supports_void')
      end

      def supports_credit?
        false
      end

      def supports_capture?
        check_support_for('supports_capture')
      end

      def supports_authorize?
        check_support_for('supports_authorize')
      end

      def supports_delete?
        # This does not check the gateway, since the redaction is specific to
        # Spreedly's store, not the gateway.
        true
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
        result = spreedly.redact_payment_method(credit_card_id(id))
        coerce_result(result)
      end

      private

      # Retrieves the gateway from Spreedly and then inspects the response to 
      # see what features it supports. This is a helper for the #supports_*?
      # predicates.
      #
      # @param String path
      # @return [true, false]
      def check_support_for(path)
        gateway = spreedly.find_gateway(gateway_token)
        node = Nokogiri::XML::DocumentFragment.parse(gateway.characteristics)
        node.xpath(".//#{path}").inner_html.strip == 'true'
      end

      # Takes the result of running a transaction against a Spreedly gateway
      # and coerces it into a SpookAndPay::Result
      #
      # @param Spreedly::Transaction result
      # @return SpookAndPay::Result
      def coerce_result(result)
        opts = {
          :transaction  => coerce_transaction(result),
          :errors       => extract_transaction_errors(result)
        }

        if result.respond_to?(:payment_method)
          opts[:credit_card] = coerce_credit_card(result.payment_method)
        end

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
        "errors.blank" => :required,
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
        expired = !card.errors.select {|e| e[:key] == 'errors.expired'}.empty?

        fields = {
          :card_type        => card.card_type,
          :number           => card.number,
          :name             => card.full_name,
          :expiration_month => card.month,
          :expiration_year  => card.year,
          :valid            => card.valid?,
          :expired          => expired
        }

        SpookAndPay::CreditCard.new(self, card.token, fields, card)
      end

      # Takes a transaction generated by the Spreedly lib and coerces it into a
      # SpookAndPay::Transaction
      #
      # @param Spreedly::Transaction transaction
      # @return SpookAndPay::Transaction
      # @todo extract created_at and status from the transaction.response
      def coerce_transaction(transaction)
        fields = {}

        fields[:type], status = case transaction
        when ::Spreedly::Authorization  then [:authorize, :authorized]
        when ::Spreedly::Purchase       then [:purchase, :settled]
        when ::Spreedly::Capture        then [:capture, :settled]
        when ::Spreedly::Refund         then [:credit, :refunded]
        when ::Spreedly::Void           then [:void, :voided]
        end

        if transaction.respond_to?(:amount)
          fields[:amount] = transaction.amount
        end

        SpookAndPay::Transaction.new(self, transaction.token, status, transaction, fields)
      end
    end
  end
end
