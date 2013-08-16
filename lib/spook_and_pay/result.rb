module SpookAndPay
  class Result
    attr_reader :transaction, :credit_card, :raw, :errors

    def initialize(successful, raw, opts = {})
      @successful   = successful
      @raw          = raw
      @transaction  = opts[:transaction] if opts.has_key?(:transaction)
      @credit_card  = opts[:credit_card] if opts.has_key?(:credit_card)
      @errors       = opts[:errors] || []
    end

    # Collects errors for a specific target, keyed by field.
    # 
    # @param Symbol target
    # @return Hash
    def errors_for(target)
      errors.select{|e| e.target == target}.reduce({}) do |h, e|
        h[e.field] ||= []
        h[e.field] << e
        h
      end
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
