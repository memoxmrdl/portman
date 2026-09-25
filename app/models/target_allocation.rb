class TargetAllocation
  attr_reader :stock, :weight

  def initialize(stock, weight)
    @stock = stock
    @weight = weight.is_a?(Float) ? Rational(weight.to_s) : weight.to_r
  end

  def ticker
    stock.ticker
  end
end
