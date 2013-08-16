module SpookAndPay
  module Adapters
    # A class which wraps the existing Braintree client and lets us use it in
    # a sane way. Specifically, it lets us have multiple sets of credentials,
    # whereas the default behaviour in the lib is to have them global
    class Braintree
      attr_reader :gateway

      def initialize(environment, merchant_id, public_key, private_key)
        _environment = case environment
        when :production then :production
        when :development, :test then :sandbox
        end

        config = ::Braintree::Configuration.new(
          :custom_user_agent  => ::Braintree::Configuration.instance_variable_get(:@custom_user_agent),
          :endpoint           => ::Braintree::Configuration.instance_variable_get(:@endpoint),
          :environment        => _environment,
          :logger             => ::Braintree::Configuration.logger,
          :merchant_id        => merchant_id,
          :private_key        => private_key,
          :public_key         => public_key
        )

        @gateway = ::Braintree::Gateway.new(config)
      end

      # Looks up the transaction from Braintree.
      #
      # @param String id
      # @return [nil, Braintree::Transaction]
      def transaction(id)
        gateway.transaction.find(id)
      end

      # Looks up credit card details from Braintree. It squashes NotFoundError
      # and just returns nil instead.
      #
      # @param String id
      # @return [Braintree::CreditCard, nil]
      def credit_card(id)
        begin
          gateway.credit_card.find(id)
        rescue ::Braintree::NotFoundError => e
          nil
        end
      end

      # Generates the hash and query string that needs to be embedded inside 
      # of a form in order to interact with Braintree's transparent redirect.
      #
      # @param Hash data
      #
      # @return String
      def transaction_data(data)
        gateway.transparent_redirect.transaction_data(data)
      end

      # 
      def confirm(query_string)
        gateway.transparent_redirect.confirm(query_string)
      end

      def transparent_redirect_url
        gateway.transparent_redirect.url
      end
    end
  end
end
