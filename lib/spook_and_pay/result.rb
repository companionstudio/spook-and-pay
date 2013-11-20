module SpookAndPay
  # A small convenience class which wraps any results coming back from a 
  # provider. This is never instanced directly, but instead instances are
  # created by the Provider classes.
  class Result
    # Readers for the various portions of a result's payload. Depending on the
    # type of request any of these may be nil.
    attr_reader :transaction, :credit_card, :raw, :errors

    # @param [true, false] successful
    # @param Class raw
    # @param Hash opts
    def initialize(successful, raw, opts = {})
      @successful   = successful
      @raw          = raw
      @transaction  = opts[:transaction] if opts.has_key?(:transaction)
      @credit_card  = opts[:credit_card] if opts.has_key?(:credit_card)
      @errors       = opts[:errors] || []
    end

    # Checks to see if a transaction is present.
    #
    # @return [true, false]
    def transaction?
      !transaction.nil?
    end

    # Checks to see if a credit card is present.
    #
    # @return [true, false]
    def credit_card?
      !credit_card.nil?
    end

    # Checks to see if any errors are present.
    #
    # @return [true, false]
    def errors?
      !errors.empty?
    end

    # Collects errors for a specific target, keyed by field.
    # 
    # @param Symbol target
    # @return Hash
    # @return Hash<Symbol, Array<SpookAndPay::SubmissionError>>
    def errors_for(target)
      errors.select{|e| e.target == target}.reduce({}) do |h, e|
        h[e.field] ||= []
        h[e.field] << e
        h
      end
    end

    # Returns the errors for a specific target and field.
    #
    # @param Symbol target
    # @param Symbol field
    # @return Array<SpookAndPay::SubmissionError>
    def errors_for_field(target, field)
      errors.select {|e| e.target == target and e.field == field}
    end

    # A nice alias for checking for success.
    #
    # @return [true, false]
    def successful?
      @successful
    end

    # A nice helper for checking for failure.
    #
    # @return [true, false]
    def failure?
      !@successful
    end
  end
end
