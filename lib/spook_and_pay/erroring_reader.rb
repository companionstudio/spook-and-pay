module SpookAndPay
  module ErroringReader
    # Defines a set of readers which will error if the underlying ivar is nil.
    # It is intended to be used with a sub-set of readers which are important,
    # but which may be nil. This is preferable to returning nil, which is falsy
    # and will screw up any predicates.
    #
    # @param Symbol ivars
    # @return nil
    def attr_erroring_reader(*ivars)
      ivars.each do |i|
        class_eval %{
          def #{i}
            raise MissingValueError.new(:#{i}, self) unless defined?(@#{i})
            @#{i}
          end
        }
      end

      nil
    end
  end
end
