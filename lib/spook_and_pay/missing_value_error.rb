module SpookAndPay
  # A simple error class used to capture situations where the user is 
  # attampting to access a value, but it is not available. This is
  # unfortunately necessary due to the way some providers do or do not
  # return certain fields. Rather than allow comparison with nil values
  # we throw this error.
  class MissingValueError < StandardError
    # When instancing this error, it needs to have enough information to point 
    # the user to the source.
    #
    # @param [String, Symbol] field
    # @param Class record
    def initialize(field, record)
      @field = field
      @record = record
    end

    # Human readable error message.
    #
    # @return String
    def to_s
      "The field #{@field} is missing for #{@record.class}"
    end
  end
end
