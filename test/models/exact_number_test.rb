require "test_helper"

class ExactNumberTest < ActiveSupport::TestCase
  test "an integer becomes an equal Rational" do
    assert_equal Rational(10), ExactNumber.from(10)
  end

  test "a float is coerced through its decimal string, avoiding binary rounding" do
    assert_equal Rational("0.1"), ExactNumber.from(0.1)
    refute_equal 0.1.to_r, ExactNumber.from(0.1)
  end

  test "a rational value is returned as an equal Rational" do
    assert_equal Rational(1, 3), ExactNumber.from(Rational(1, 3))
  end
end
