require "test_helper"

class PortfolioTest < ActiveSupport::TestCase
  setup do
    @meta = Stock.new("META")
    @appl = Stock.new("APPL")
    @portfolio = Portfolio.new
  end

  test "a holding records quantity for META" do
    @portfolio.hold(@meta, 50)

    holding = @portfolio.holdings.find { |item| item.ticker == "META" }
    assert_equal 50, holding.quantity
    assert_equal 50, @portfolio.quantity_for("META")
  end

  test "multiple holdings are recorded independently" do
    @portfolio.hold(@meta, 40)
    @portfolio.hold(@appl, 60)

    assert_equal 40, @portfolio.quantity_for("META")
    assert_equal 60, @portfolio.quantity_for("APPL")
  end

  test "zero quantity is treated as not held" do
    @portfolio.hold(@meta, 0)

    refute @portfolio.holdings.any? { |item| item.ticker == "META" }
    assert_equal 0, @portfolio.quantity_for("META")
  end

  test "negative quantity is rejected" do
    assert_raises(DomainError::InvalidQuantity) { @portfolio.hold(@meta, -1) }
    refute @portfolio.holdings.any? { |item| item.ticker == "META" }
  end

  test "duplicate ticker holdings are rejected" do
    @portfolio.hold(@meta, 10)
    assert_raises(DomainError::DuplicateTicker) { @portfolio.hold(@meta, 5) }
    assert_equal 1, @portfolio.holdings.count { |item| item.ticker == "META" }
    assert_equal 10, @portfolio.quantity_for("META")
  end

  test "canonical META 40 and APPL 60 allocation keeps ticker APPL" do
    @portfolio.allocate(@meta => 40, @appl => 60)

    weights = allocation_weights
    assert_equal 0.4, weights["META"]
    assert_equal 0.6, weights["APPL"]
    assert @portfolio.allocations.any? { |item| item.ticker == "APPL" }
    refute @portfolio.allocations.any? { |item| item.ticker == "AAPL" }
  end

  test "allocated ticker need not be held" do
    @portfolio.allocate(@meta => 40, @appl => 60)

    assert @portfolio.allocations.any? { |item| item.ticker == "APPL" }
    refute @portfolio.holdings.any? { |item| item.ticker == "APPL" }
    assert_equal 0, @portfolio.quantity_for("APPL")
  end

  test "duplicate ticker allocations are rejected" do
    other_meta = Stock.new("META")
    assert_raises(DomainError::DuplicateTicker) do
      @portfolio.allocate(@meta => 40, other_meta => 60)
    end
  end

  test "percent weights that sum to 100 are accepted" do
    @portfolio.allocate(@meta => 40, @appl => 60)
    assert_equal 2, @portfolio.allocations.size
  end

  test "unit weights that sum to 1.0 are accepted" do
    @portfolio.allocate(@meta => 0.4, @appl => 0.6)
    weights = allocation_weights
    assert_equal 0.4, weights["META"]
    assert_equal 0.6, weights["APPL"]
  end

  test "a single 100 percent target is accepted" do
    @portfolio.allocate(@meta => 100)
    assert_equal 1, allocation_weights["META"]
  end

  test "a single 1.0 target is accepted" do
    @portfolio.allocate(@meta => 1.0)
    assert_equal 1, allocation_weights["META"]
  end

  test "weights that sum to 90 percent are rejected" do
    assert_raises(DomainError::InvalidAllocation) { @portfolio.allocate(@meta => 40, @appl => 50) }
  end

  test "weights that sum to more than 100 percent are rejected" do
    assert_raises(DomainError::InvalidAllocation) { @portfolio.allocate(@meta => 40, @appl => 70) }
  end

  test "mixed percent and unit weights are rejected" do
    assert_raises(DomainError::InvalidAllocation) { @portfolio.allocate(@meta => 40, @appl => 0.6) }
  end

  test "empty allocation is rejected" do
    assert_raises(DomainError::InvalidAllocation) { @portfolio.allocate({}) }
  end

  test "a name is held and not allocated" do
    other = Stock.new("OTHER")
    @portfolio.hold(other, 10)
    @portfolio.allocate(@meta => 100)

    assert @portfolio.holdings.any? { |item| item.ticker == "OTHER" }
    refute @portfolio.allocations.any? { |item| item.ticker == "OTHER" }
    assert @portfolio.allocations.any? { |item| item.ticker == "META" }
  end

  test "a name is allocated and not held" do
    @portfolio.hold(@meta, 10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    assert @portfolio.allocations.any? { |item| item.ticker == "APPL" }
    refute @portfolio.holdings.any? { |item| item.ticker == "APPL" && item.quantity.positive? }
  end

  test "empty holdings with a valid allocation are representable" do
    @portfolio.allocate(@meta => 40, @appl => 60)

    assert_equal 2, @portfolio.allocations.size
    assert_empty @portfolio.holdings
  end

  test "APPL remains APPL in holdings and allocations" do
    @portfolio.hold(@appl, 60)
    @portfolio.allocate(@meta => 40, @appl => 60)

    assert @portfolio.holdings.any? { |item| item.ticker == "APPL" }
    assert @portfolio.allocations.any? { |item| item.ticker == "APPL" }
    refute @portfolio.holdings.any? { |item| item.ticker == "AAPL" }
    refute @portfolio.allocations.any? { |item| item.ticker == "AAPL" }
  end

  private

  def allocation_weights
    @portfolio.allocations.each_with_object({}) { |item, hash| hash[item.ticker] = item.weight }
  end
end
