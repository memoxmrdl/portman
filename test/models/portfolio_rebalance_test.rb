require "test_helper"

class PortfolioRebalanceTest < ActiveSupport::TestCase
  setup do
    @meta = Stock.new("META")
    @appl = Stock.new("APPL")
    @portfolio = Portfolio.new
  end

  test "rebalance returns a plan and leaves holdings unchanged" do
    book(meta_qty: 50, appl_qty: 50, meta_price: 10, appl_price: 10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance

    assert_instance_of RebalancePlan, plan
    assert_equal 50, @portfolio.quantity_for("META")
    assert_equal 50, @portfolio.quantity_for("APPL")
  end

  test "canonical 50/50 book sells 10 META and buys 10 APPL" do
    book(meta_qty: 50, appl_qty: 50, meta_price: 10, appl_price: 10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance
    by_ticker = instructions_by_ticker(plan)

    assert_equal :sell, by_ticker["META"].side
    assert_equal 10, by_ticker["META"].quantity
    assert_equal :buy, by_ticker["APPL"].side
    assert_equal 10, by_ticker["APPL"].quantity
    assert plan.instructions.all? { |instruction| instruction.quantity.positive? }
    assert_equal [ "APPL", "META" ], plan.instructions.map(&:ticker)
    refute plan.instructions.any? { |instruction| instruction.ticker == "AAPL" }
  end

  test "zero-delta names are omitted from the plan" do
    other = Stock.new("OTHER")
    other.current_price(10)
    @meta.current_price(10)
    @appl.current_price(10)
    @portfolio.hold(@meta, 40)
    @portfolio.hold(@appl, 50)
    @portfolio.hold(other, 10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance
    tickers = plan.instructions.map(&:ticker)

    refute_includes tickers, "META"
    assert_includes tickers, "APPL"
    assert_includes tickers, "OTHER"
  end

  test "fractional share quantities are recommended" do
    book(meta_qty: 1, appl_qty: 1, meta_price: 3, appl_price: 6)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance
    by_ticker = instructions_by_ticker(plan)

    assert_equal :buy, by_ticker["META"].side
    assert_equal 0.2, by_ticker["META"].quantity
    assert_equal :sell, by_ticker["APPL"].side
    assert_equal 0.1, by_ticker["APPL"].quantity
    refute_equal 0, by_ticker["META"].quantity
    refute_equal 1, by_ticker["META"].quantity
  end

  test "unequal prices still follow value-drift" do
    book(meta_qty: 10, appl_qty: 5, meta_price: 20, appl_price: 20)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance
    by_ticker = instructions_by_ticker(plan)

    assert_equal :sell, by_ticker["META"].side
    assert_equal 4, by_ticker["META"].quantity
    assert_equal :buy, by_ticker["APPL"].side
    assert_equal 4, by_ticker["APPL"].quantity
  end

  test "empty plan when already at 40 percent META and 60 percent APPL" do
    book(meta_qty: 40, appl_qty: 60, meta_price: 10, appl_price: 10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance

    assert plan.empty?
    assert_equal 40, @portfolio.quantity_for("META")
    assert_equal 60, @portfolio.quantity_for("APPL")
  end

  test "empty plan for a single 100 percent META holding" do
    @meta.current_price(5)
    @portfolio.hold(@meta, 7)
    @portfolio.allocate(@meta => 100)

    plan = @portfolio.rebalance
    assert plan.empty?
  end

  test "unallocated holding is sold to zero" do
    other = Stock.new("OTHER")
    other.current_price(10)
    @meta.current_price(10)
    @portfolio.hold(@meta, 10)
    @portfolio.hold(other, 5)
    @portfolio.allocate(@meta => 100)

    plan = @portfolio.rebalance
    by_ticker = instructions_by_ticker(plan)

    assert_equal :sell, by_ticker["OTHER"].side
    assert_equal 5, by_ticker["OTHER"].quantity
    assert_equal :buy, by_ticker["META"].side
    assert_equal 5, by_ticker["META"].quantity
  end

  test "sell-to-zero uses the current quantity" do
    other = Stock.new("OTHER")
    other.current_price(10)
    @meta.current_price(10)
    @portfolio.hold(@meta, 10)
    @portfolio.hold(other, 2.5)
    @portfolio.allocate(@meta => 100)

    plan = @portfolio.rebalance
    by_ticker = instructions_by_ticker(plan)

    assert_equal :sell, by_ticker["OTHER"].side
    assert_equal 2.5, by_ticker["OTHER"].quantity
  end

  test "allocated name that is not held is bought from scratch" do
    book(meta_qty: 10, appl_qty: 0, meta_price: 10, appl_price: 10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance
    by_ticker = instructions_by_ticker(plan)

    assert_equal :sell, by_ticker["META"].side
    assert_equal 6, by_ticker["META"].quantity
    assert_equal :buy, by_ticker["APPL"].side
    assert_equal 6, by_ticker["APPL"].quantity
    assert_equal 0, @portfolio.quantity_for("APPL")
  end

  test "buy-from-scratch uses the allocated name stored price" do
    book(meta_qty: 10, appl_qty: 0, meta_price: 10, appl_price: 25)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance
    by_ticker = instructions_by_ticker(plan)

    assert_equal 2.4, by_ticker["APPL"].quantity
    assert_equal :buy, by_ticker["APPL"].side
  end

  test "missing price on a held allocated name fails the whole call" do
    @appl.current_price(10)
    @portfolio.hold(@meta, 50)
    @portfolio.hold(@appl, 50)
    @portfolio.allocate(@meta => 40, @appl => 60)

    assert_raises(DomainError::UnpricedInstrument) { @portfolio.rebalance }
    assert_equal 50, @portfolio.quantity_for("META")
    assert_equal 50, @portfolio.quantity_for("APPL")
  end

  test "missing price on an allocated unheld name fails the whole call" do
    @meta.current_price(10)
    @portfolio.hold(@meta, 10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    assert_raises(DomainError::UnpricedInstrument) { @portfolio.rebalance }
    assert_equal 10, @portfolio.quantity_for("META")
  end

  test "missing price on an unallocated holding fails the whole call" do
    other = Stock.new("OTHER")
    @meta.current_price(10)
    @portfolio.hold(@meta, 10)
    @portfolio.hold(other, 5)
    @portfolio.allocate(@meta => 100)

    assert_raises(DomainError::UnpricedInstrument) { @portfolio.rebalance }
    assert_equal 5, @portfolio.quantity_for("OTHER")
  end

  test "blank zero and negative prices fail rebalance" do
    @meta.current_price(10)
    @appl.current_price(10)
    @portfolio.hold(@meta, 50)
    @portfolio.hold(@appl, 50)
    @portfolio.allocate(@meta => 40, @appl => 60)

    assert_raises(DomainError::InvalidPrice) { @appl.current_price("") }
    assert_equal 10, @appl.last_available_price

    unpriced = Stock.new("OTHER")
    @portfolio.hold(unpriced, 1)
    assert_raises(DomainError::UnpricedInstrument) { @portfolio.rebalance }
  end

  test "zero price cannot be stored so rebalance fails closed" do
    @meta.current_price(10)
    @portfolio.hold(@meta, 10)
    @portfolio.allocate(@meta => 40, @appl => 60)
    assert_raises(DomainError::InvalidPrice) { @appl.current_price(0) }
    assert_raises(DomainError::UnpricedInstrument) { @portfolio.rebalance }
  end

  test "negative price cannot be stored so rebalance fails closed" do
    @meta.current_price(10)
    @portfolio.hold(@meta, 10)
    @portfolio.allocate(@meta => 40, @appl => 60)
    assert_raises(DomainError::InvalidPrice) { @appl.current_price(-5) }
    assert_raises(DomainError::UnpricedInstrument) { @portfolio.rebalance }
  end

  test "recommended trades consume the full book value with leftover 0" do
    book(meta_qty: 50, appl_qty: 50, meta_price: 10, appl_price: 10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance
    values = applied_values(plan, prices: { "META" => 10, "APPL" => 10 })

    refute plan.instructions.any? { |instruction| instruction.ticker == "CASH" }
    assert_equal 400, values["META"]
    assert_equal 600, values["APPL"]
    assert_equal 0, 1000 - values.values.sum
  end

  test "fractional happy path has no residual drift" do
    book(meta_qty: 1, appl_qty: 1, meta_price: 3, appl_price: 6)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance
    values = applied_values(plan, prices: { "META" => 3, "APPL" => 6 })
    total = 9.to_r

    assert_equal total * Rational("0.4"), values["META"]
    assert_equal total * Rational("0.6"), values["APPL"]
    assert_equal 0, total - values.values.sum
  end

  test "empty holdings fail rebalance" do
    @meta.current_price(10)
    @appl.current_price(10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    assert_raises(DomainError::NonPositiveTotal) { @portfolio.rebalance }
  end

  test "all-zero quantities fail rebalance" do
    @meta.current_price(10)
    @appl.current_price(10)
    @portfolio.hold(@meta, 0)
    @portfolio.hold(@appl, 0)
    @portfolio.allocate(@meta => 40, @appl => 60)

    assert_raises(DomainError::NonPositiveTotal) { @portfolio.rebalance }
  end

  test "plan uses stored prices rather than a call-time quote" do
    book(meta_qty: 50, appl_qty: 50, meta_price: 10, appl_price: 10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    plan = @portfolio.rebalance
    by_ticker = instructions_by_ticker(plan)

    assert_equal 10, by_ticker["META"].quantity
    assert_equal 10, by_ticker["APPL"].quantity
  end

  test "updated stored price changes the next plan" do
    book(meta_qty: 50, appl_qty: 50, meta_price: 10, appl_price: 10)
    @portfolio.allocate(@meta => 40, @appl => 60)

    first = @portfolio.rebalance
    @meta.current_price(20)
    second = @portfolio.rebalance

    refute_equal instructions_by_ticker(first)["META"].quantity, instructions_by_ticker(second)["META"].quantity
    assert_equal 50, @portfolio.quantity_for("META")
    assert_equal 50, @portfolio.quantity_for("APPL")
  end

  test "invalid 40 plus 50 allocation fails rebalance" do
    book(meta_qty: 50, appl_qty: 50, meta_price: 10, appl_price: 10)
    assert_raises(DomainError::InvalidAllocation) { @portfolio.allocate(@meta => 40, @appl => 50) }
    assert_raises(DomainError::InvalidAllocation) { @portfolio.rebalance }
    assert_equal 50, @portfolio.quantity_for("META")
    assert_equal 50, @portfolio.quantity_for("APPL")
  end

  private

  def book(meta_qty:, appl_qty:, meta_price:, appl_price:)
    @meta.current_price(meta_price)
    @appl.current_price(appl_price)
    @portfolio.hold(@meta, meta_qty) unless meta_qty == 0
    @portfolio.hold(@appl, appl_qty) unless appl_qty == 0
  end

  def instructions_by_ticker(plan)
    plan.instructions.each_with_object({}) { |instruction, hash| hash[instruction.ticker] = instruction }
  end

  def applied_values(plan, prices:)
    quantities = { "META" => @portfolio.quantity_for("META"), "APPL" => @portfolio.quantity_for("APPL") }
    plan.instructions.each do |instruction|
      quantities[instruction.ticker] ||= 0.to_r
      delta = instruction.quantity
      quantities[instruction.ticker] += instruction.side == :buy ? delta : -delta
    end
    quantities.each_with_object({}) do |(ticker, quantity), hash|
      next unless prices.key?(ticker)

      hash[ticker] = quantity * prices[ticker].to_r
    end
  end
end
