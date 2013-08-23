module SpookAndPay
  # A simple class representing an interaction with a provider. Each 
  # interaction has an ID, a type and may be successful or not. It is 
  # read-only.
  class Transaction
    # Basic attributes
    attr_reader :provider, :id, :status, :raw

    # Extra set of fields which may or may not be present depending on the 
    # provider.
    FIELDS = [:created_at, :updated_at, :amount, :credit_card, :type].freeze
    attr_reader *FIELDS

    # The basic types for transactions.
    TYPES = [:purchase, :authorize, :capture, :credit, :void].freeze

    # Acceptable set of statuses.
    STATUSES = [:authorized, :settling, :settled, :voided, :refunded, :gateway_rejected].freeze

    # An error thrown when attempting to perform an action that is not allowed
    # given a transaction's status.
    class InvalidActionError < StandardError
      # @param String id
      # @param Symbol action
      # @param Symbol status
      def initialize(id, action, status)
        @id     = id
        @action = action
        @status = status
      end

      # Human readable message.
      #
      # @return String
      def to_s
        "Cannot perform the action '#{@action}' for transaction '#{@id}' while in status '#{@status}'"
      end
    end

    # As a bare minimum the transaction captures the transaction ID, it's 
    # status and the raw response from the provider. Optionally, it can receive
    # other fields via the opts hash.
    #
    # @param SpookAndPay::Providers::Base provider
    # @param String id
    # @param [String, nil] status
    # @param Class raw
    # @param Hash opts
    # @option opts SpookAndPay::CreditCard :credit_card
    # @option opts Time :created_at
    # @option opts Time :updated_at
    # @option opts BigDecimal :amount
    # @option opts String :type
    def initialize(provider, id, status, raw, opts = {})
      @provider   = provider
      @id         = id
      @status     = status.to_sym if status
      @raw        = raw

      FIELDS.each {|f| instance_variable_set(:"@#{f}", opts[f]) if opts.has_key?(f)}
    end

    # Implements value comparison i.e. if class and ID match, they are the 
    # same.
    #
    # @param Class other
    # @return [true, false]
    def ==(other)
      other.is_a?(SpookAndPay::Transaction) and other.id == id
    end

    # A simple predicate to see if the payment has been settled.
    #
    # @return [true, false]
    def settled?
      status == :settled
    end

    # A simple predicate which indicates if the payment is in the process of
    # being settled.
    #
    # @return [true, false]
    def settling?
      status == :settling
    end

    # A simple predicate to check if the payment has been authorized.
    #
    # @return [true, false]
    def authorized?
      status == :authorized
    end

    # A predicate for checking if a transaction can be refunded. Only true if
    # the status is :settled
    #
    # @return [true, false]
    def can_refund?
      status == :settled
    end

    # A predicate for checking if a transaction can be captured. Only true if
    # the status is :authorized
    #
    # @return [true, false]
    def can_capture?
      status == :authorized
    end

    # A predicate for checking if a transaction can be voided. Only true if
    # the status is :authorized or :submitted_for_settlement
    #
    # @return [true, false]
    def can_void?
      status == :authorized or status == :settling
    end

    # Refunds the transaction. The related credit card will be credited for
    # the amount captured. It will only succeed for purchases or captured
    # authorizations.
    #
    # @return SpookAndPay::Result
    # @raises InvalidActionError
    def refund!
      raise InvalidActionError.new(id, :refund, status) unless can_refund?
      provider.refund_transaction(self)
    end

    # Captures an authorized transaction. Will only capture the amount 
    # authorized and will fail if the transaction is already captured.
    #
    # @return SpookAndPay::Result
    # @raises InvalidActionError
    def capture!
      raise InvalidActionError.new(id, :capture, status) unless can_capture?
      provider.capture_transaction(self)
    end

    # Voids a transaction. Can only be done when the transaction is in the 
    # authorized status. Otherwise it must be refunded.
    #
    # @return SpookAndPay::Result
    # @raises InvalidActionError
    def void!
      raise InvalidActionError.new(id, :void, status) unless can_void?
      provider.void_transaction(self)
    end
  end
end
