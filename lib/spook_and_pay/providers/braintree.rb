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

      # Confirms the submission of payment details to the provider.
      #
      # @param String query_string
      #
      # @return SpookAndPay::Result
      def confirm_payment_submission(query_string)
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
        "81715" => [:credit_card, :invalid_number, :number],
        "81703" => [:credit_card, :type_not_accepted, :card_type],
        "81716" => [:credit_card, :wrong_length, :number],
        "81712" => [:credit_card, :invalid_expiration_month, :expiration_month],
        "81713" => [:credit_card, :invalid_expiration_year, :expiration_year],
        "81707" => [:credit_card, :invalid_cvv, :cvv],
        "91507" => [:transaction, :cannot_capture, :status],
        "91506" => [:transaction, :cannot_refund, :status],
        "91504" => [:transaction, :cannot_void, :status]
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
            :expiration_year  => card[:expiration_year]
          }
        else
          {
            :token            => card.token,
            :card_type        => card.card_type,
            :number           => card.last_4,
            :name             => card.cardholder_name,
            :expiration_month => card.expiration_month,
            :expiration_year  => card.expiration_year
          }
        end

        SpookAndPay::CreditCard.new(self, opts.delete(:token), valid, expired, opts)
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
          payload[:amount] = result[:amount] if result.has_key?(:amount)

          SpookAndPay::Transaction.new(
            self,
            result[:id],
            result[:type].to_sym,
            result[:created_at],
            result[:status],
            payload
          ) 
        else
          payload[:amount] = result.amount unless result.amount.nil?

          SpookAndPay::Transaction.new(
            self,
            result.id,
            result.type.to_sym,
            result.created_at,
            result.status,
            payload
          ) 
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

      def payment_submission_url
        adapter.transparent_redirect_url
      end

      # Hidden fields used by the Braintree provider.
      #
      # @param Hash opts
      # @option opts String :amount
      # @option opts [true, false] :store_in_vault
      def payment_hidden_fields(type, opts)
        payload = {
          :transaction  => {:type => opts[:type] || 'sale', :amount => opts[:amount]},
          :redirect_url => opts[:redirect_url]
        }

        if opts[:vault]
          (payload[:transaction][:options] ||= {})[:store_in_vault] = true
        end

        if type == :purchase
          (payload[:transaction][:options] ||= {})[:submit_for_settlement] = true
        end

        {:tr_data => adapter.transaction_data(payload)}
      end
    end
  end
end
