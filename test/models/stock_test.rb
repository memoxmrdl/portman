require "test_helper"

class StockTest < ActiveSupport::TestCase
  test "META ticker is stored as given" do
    stock = Stock.new("META")
    assert_equal "META", stock.ticker
  end

  test "APPL ticker is not rewritten to AAPL" do
    stock = Stock.new("APPL")
    assert_equal "APPL", stock.ticker
    refute_equal "AAPL", stock.ticker
  end

  test "distinct tickers remain distinct" do
    meta = Stock.new("META")
    appl = Stock.new("APPL")
    refute_equal meta.ticker, appl.ticker
  end

  test "blank or missing ticker is rejected" do
    assert_raises(DomainError::InvalidTicker) { Stock.new(nil) }
    assert_raises(DomainError::InvalidTicker) { Stock.new("") }
    assert_raises(DomainError::InvalidTicker) { Stock.new("   ") }
  end

  test "current_price stores and returns a valid price" do
    stock = Stock.new("META")
    returned = stock.current_price(10)

    assert_equal 10, returned
    assert_equal 10, stock.last_available_price
    assert stock.priced?
  end

  test "a later valid price overwrites the previous price" do
    stock = Stock.new("META")
    stock.current_price(10)
    returned = stock.current_price(12.5)

    assert_equal 12.5, returned
    assert_equal 12.5, stock.last_available_price
    refute_equal 10, stock.last_available_price
  end

  test "subsequent reads without a new price return the stored value" do
    stock = Stock.new("META")
    stock.current_price(8)

    assert_equal 8, stock.last_available_price
  end

  test "missing price is invalid and leaves the stock unpriced" do
    stock = Stock.new("META")
    assert_raises(DomainError::InvalidPrice) { stock.current_price }
    refute stock.priced?
    assert_nil stock.last_available_price
  end

  test "blank price is invalid and leaves the stock unpriced" do
    stock = Stock.new("APPL")
    assert_raises(DomainError::InvalidPrice) { stock.current_price("") }
    assert_raises(DomainError::InvalidPrice) { stock.current_price("  ") }
    refute stock.priced?
  end

  test "zero price is invalid and leaves the stock unpriced" do
    stock = Stock.new("META")
    assert_raises(DomainError::InvalidPrice) { stock.current_price(0) }
    refute stock.priced?
  end

  test "negative price is invalid and leaves the stock unpriced" do
    stock = Stock.new("META")
    assert_raises(DomainError::InvalidPrice) { stock.current_price(-5) }
    refute stock.priced?
  end

  test "an invalid price does not clobber a stored valid price" do
    stock = Stock.new("META")
    stock.current_price(10)

    assert_raises(DomainError::InvalidPrice) { stock.current_price }
    assert_raises(DomainError::InvalidPrice) { stock.current_price("") }
    assert_raises(DomainError::InvalidPrice) { stock.current_price(0) }
    assert_raises(DomainError::InvalidPrice) { stock.current_price(-5) }

    assert_equal 10, stock.last_available_price
    assert stock.priced?
  end
end
