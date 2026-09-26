class Holding
  attr_reader :stock, :quantity

  def initialize(stock, quantity)
    @stock = stock
    @quantity = ExactNumber.from(quantity)
  end

  def ticker
    stock.ticker
  end
end
