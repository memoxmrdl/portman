class Holding
  attr_reader :stock, :quantity

  def initialize(stock, quantity)
    @stock = stock
    @quantity = quantity.is_a?(Float) ? Rational(quantity.to_s) : quantity.to_r
  end

  def ticker
    stock.ticker
  end
end
