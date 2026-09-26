module ExactNumber
  # Coerce any Numeric to an exact Rational.
  #
  # A Float goes through its decimal String first: Float#to_r exposes the raw
  # IEEE-754 binary value (e.g. 0.1.to_r => 3602879701896397/36028797018963968),
  # while Rational(value.to_s) captures the decimal digits as typed/displayed.
  def self.from(value)
    value.is_a?(Float) ? Rational(value.to_s) : value.to_r
  end
end
