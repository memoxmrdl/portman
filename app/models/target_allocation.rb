class TargetAllocation
  attr_reader :stock, :weight

  def initialize(stock, weight)
    @stock = stock
    @weight = ExactNumber.from(weight)
  end

  def ticker
    stock.ticker
  end
end
