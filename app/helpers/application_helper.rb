module ApplicationHelper
  def format_quantity(value)
    rational = value.to_r
    rational.denominator == 1 ? rational.numerator.to_s : rational.to_f.to_s
  end
end
