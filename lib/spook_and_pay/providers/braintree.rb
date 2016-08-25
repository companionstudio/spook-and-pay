module SpookAndPay
  module Providers
    class Braintree < Base
      FORM_FIELD_NAMES = {
        :name             => "transaction[credit_card][cardholder_name]",
        :number           => "transaction[credit_card][number]",
        :expiration_month => "transaction[credit_card][expiration_month]",
        :expiration_year  => "transaction[credit_card][expiration_year]",
        :cvv              => "transaction[credit_card][cvv]"
      }.freeze

      attr_reader :adapter

      # @param Hash config
      # @option config String :merchant_id
      # @option config String :public_key
      # @option config String :private_key
      def initialize(env, config)
        @adapter = SpookAndPay::Adapters::Braintree.new(
          env,
          config[:merchant_id],
          config[:public_key],
          config[:private_key]
        )

        super(env, config)
      end

      # Braintree specific version of this method. Can be used to either
      # authorize a payment — and capture it later — or submit a payment for
      # settlement immediately. This is done via the type param.
      #
      # Because Braintree accepts payment details and processes payment in a
      # single step, this method must also be provided with an amount.
      #
      # @param String redirect_url
      # @param Hash opts
      # @option opts [true, false] :vault
      # @option opts [:purchase, :authorize] :type
      # @option opts [String, Numeric] :amount
      # @return Hash
      def prepare_payment_submission(redirect_url, opts = {})
        payload = {
          :transaction  => {:type => 'sale', :amount => opts[:amount]},
          :redirect_url => redirect_url
        }

        if opts[:vault]
          (payload[:transaction][:options] ||= {})[:store_in_vault] = true
        end

        if opts[:type] == :purchase
          (payload[:transaction][:options] ||= {})[:submit_for_settlement] = true
        end

        {
          :url            => adapter.transparent_redirect_url,
          :hidden_fields  => {:tr_data => adapter.transaction_data(payload)},
          :field_names    => self.class::FORM_FIELD_NAMES
        }
      end

      # Confirms the submission of payment details to the provider.
      #
      # @param String query_string
      # @return SpookAndPay::Result
      def confirm_payment_submission(query_string, opts = {})
        result = adapter.confirm(query_string)

        case result
        when ::Braintree::SuccessfulResult
          SpookAndPay::Result.new(
            true,
            result,
            :credit_card => extract_credit_card(result.transaction.credit_card_details, true, false),
            :transaction => extract_transaction(result.transaction)
          )
        when ::Braintree::ErrorResult
          SpookAndPay::Result.new(
            false,
            result,
            :credit_card => extract_credit_card(result.params[:transaction][:credit_card], false, false),
            :transaction => extract_transaction(result.params[:transaction]),
            :errors => extract_errors(result)
          )
        end
      end

      def credit_card(id)
        result = adapter.credit_card(id)
        extract_credit_card(result, true, false) if result
      end

      def credit_card_from_transaction(id)
        _id = id.is_a?(String) ? id : id.id
        result = adapter.transaction(_id)
        extract_credit_card(result.credit_card_details, true, false)
      end

      def transaction(id)
        result = adapter.transaction(id)
        extract_transaction(result) if result
      end

      def capture_transaction(id)
        result = adapter.capture(transaction_id(id))
        generate_result(result)
      end

      def refund_transaction(id)
        result = adapter.refund(transaction_id(id))
        generate_result(result)
      end

      def partially_refund_transaction(id, amount)
        result = adapter.partially_refund(transaction_id(id), amount)
        generate_result(result)
      end

      def void_transaction(id)
        result = adapter.void(transaction_id(id))
        generate_result(result)
      end

      private

      # Maps the error codes returned by Braintree to a triple of target, type
      # and field used by the SubmissionError class.
      #
      # The key is the error code from Braintree. The first entry in the triple
      # is the specific portion of the transaction that has the error. The
      # second is the type of error and the third is the field — if any — it
      # applies to.
      ERROR_CODE_MAPPING = {
        "81715" => [:credit_card, :invalid, :number],
        "81725" => [:credit_card, :required, :number],
        "81703" => [:credit_card, :type_not_accepted, :card_type],
        "81716" => [:credit_card, :too_short, :number],
        "81712" => [:credit_card, :invalid, :expiration_month],
        "81713" => [:credit_card, :invalid, :expiration_year],
        "81707" => [:credit_card, :invalid, :cvv],
        "91507" => [:transaction, :cannot_capture, :transaction],
        "91506" => [:transaction, :cannot_refund, :transaction],
        "91504" => [:transaction, :cannot_void, :transaction]
      }.freeze

      # Extracts errors from the collection returned by Brain tree and coerces
      # them into an array of SubmissionError.
      #
      # @param Braintree:ErrorResult result
      # @return Array<SpookAndPay::Providers::Base::SubmissionError>
      def extract_errors(result)
        result.errors.map do |e|
          mapping = ERROR_CODE_MAPPING[e.code]
          if mapping
            SubmissionError.new(*mapping, e)
          else
            SubmissionError.new(:unknown, :unknown, :unknown, e)
          end
        end
      end

      # A generic method for generating results on actions. It doesn't capture
      # anything action specific i.e. it might need to be replaced later.
      #
      # @param [Braintree::SuccessfulResult, Braintree:ErrorResult] result
      # @return SpookAndPay::Result
      def generate_result(result)
        case result
        when ::Braintree::SuccessfulResult
          SpookAndPay::Result.new(
            true,
            result,
            :credit_card => extract_credit_card(result.transaction.credit_card_details, true, false),
            :transaction => extract_transaction(result.transaction)
          )
        when ::Braintree::ErrorResult
          SpookAndPay::Result.new(
            false,
            result,
            :errors => extract_errors(result)
          )
        end
      end

      # Extracts credit card details from a payload extracted from a result.
      # It could be either a Hash, Braintree::CreditCard or
      # Braintree::Transaction::CreditCardDetails. BOO!
      #
      # @param [Hash, Braintree::CreditCard, Braintree::Transaction::CreditCardDetails] card
      # @param [true, false] valid
      # @param [true, false] expired
      # @return SpookAndPay::CreditCard
      #
      # @todo figure out validity and expiry ourselves
      def extract_credit_card(card, valid, expired)
        opts = case card
        when Hash
          {
            :token            => card[:token],
            :card_type        => card[:card_type],
            :number           => card[:last_4],
            :name             => card[:cardholder_name],
            :expiration_month => card[:expiration_month],
            :expiration_year  => card[:expiration_year],
            :expired          => card[:expired].nil? ? card_expired?(card[:expiration_month], card[:expiration_year]) : card[:expired],
            :valid            => true # We have to assume it's valid, since BT won't say
          }
        else
          {
            :token            => card.token,
            :card_type        => card.card_type,
            :number           => card.last_4,
            :name             => card.cardholder_name,
            :expiration_month => card.expiration_month,
            :expiration_year  => card.expiration_year,
            :expired          => card.expired?,
            :valid            => true # We have to assume it's valid, since BT won't say
          }
        end

        SpookAndPay::CreditCard.new(self, opts.delete(:token), opts)
      end

      # Checks to see if a credit card has expired.
      #
      # @param Number month
      # @param Number year
      # @return [true, false]
      def card_expired?(month, year)
        now = Time.now
        month < now.month or year < now.year
      end

      # Extracts transaction details from whatever payload is passed in. This
      # might be Hash or a Braintree:Transaction.
      #
      # @param [Hash, Braintree::Transaction] result
      # @param [true, false] successful
      # @param Hash payload
      # @return SpookAndPay::Transaction
      #
      # @todo Coerce type into what we know is valid
      def extract_transaction(result, payload = {})
        case result
        when Hash
          SpookAndPay::Transaction.new(
            self,
            result[:id],
            coerce_transaction_status(result[:status]),
            result,
            :type       => result[:type].to_sym,
            :created_at => result[:created_at],
            :amount     => result[:amount]
          )
        else
          SpookAndPay::Transaction.new(
            self,
            result.id,
            coerce_transaction_status(result.status),
            result,
            :type       => result.type.to_sym,
            :created_at => result.created_at,
            :amount     => result.amount
          )
        end
      end

      # Coerces the status into a value expected by the Transaction class.
      #
      # @param [String, nil] status
      # @return [String, nil]
      def coerce_transaction_status(status)
        case status
        when 'submitted_for_settlement' then 'settling'
        else status
        end
      end

      # Based on the status of a transaction, make some determination of how of
      # whether or not is is successful.
      #
      # @param String status
      # @return [true, false]
      #
      # @todo Expand this to be more robust.
      def coerce_transaction_success(status)
        case status
        when 'authorized' then true
        else false
        end
      end
    end
  end
end
