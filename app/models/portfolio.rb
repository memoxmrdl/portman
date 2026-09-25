class Portfolio
  def initialize
    @registry = {}
    @holdings = {}
    @allocations = {}
  end

  def hold(stock, quantity)
    qty = coerce_rational(quantity, error: DomainError::InvalidQuantity)
    raise DomainError::InvalidQuantity if qty.negative?

    if qty.zero?
      @holdings.delete(stock.ticker)
      return
    end

    register!(stock)
    raise DomainError::DuplicateTicker if @holdings.key?(stock.ticker)

    @holdings[stock.ticker] = Holding.new(stock, qty)
  end

  def allocate(weights)
    raise DomainError::InvalidAllocation if weights.nil? || weights.empty?

    seen = {}
    entries = weights.map do |stock, weight|
      raise DomainError::InvalidAllocation unless stock.is_a?(Stock)
      raise DomainError::DuplicateTicker if seen[stock.ticker]

      seen[stock.ticker] = true
      register!(stock)
      [ stock, coerce_rational(weight, error: DomainError::InvalidAllocation) ]
    end

    sum = entries.reduce(0.to_r) { |total, (_, weight)| total + weight }
    scale = if sum == 100
      100.to_r
    elsif sum == 1
      1.to_r
    else
      raise DomainError::InvalidAllocation
    end

    @allocations = {}
    entries.each do |stock, weight|
      unit = weight / scale
      raise DomainError::InvalidAllocation unless unit >= 0 && unit <= 1

      @allocations[stock.ticker] = TargetAllocation.new(stock, unit)
    end
  end

  def holdings
    @holdings.values
  end

  def allocations
    @allocations.values
  end

  def quantity_for(ticker)
    @holdings[ticker]&.quantity || 0.to_r
  end

  def rebalance
    # Recommend-only: do not mutate holdings, allocations, or stored prices.
    raise DomainError::InvalidAllocation if @allocations.empty?

    tickers = (@holdings.keys | @allocations.keys).sort
    prices = {}
    tickers.each do |ticker|
      stock = @registry.fetch(ticker)
      # Fail on missing price: every ticker in holdings ∪ targets must be priced.
      raise DomainError::UnpricedInstrument unless stock.priced?

      prices[ticker] = stock.last_available_price
    end

    values = {}
    total = 0.to_r
    tickers.each do |ticker|
      values[ticker] = quantity_for(ticker) * prices[ticker]
      total += values[ticker]
    end
    raise DomainError::NonPositiveTotal unless total.positive?

    instructions = tickers.filter_map do |ticker|
      weight = @allocations[ticker]&.weight || 0.to_r
      target_value = weight * total
      # Rounding identity: applying every recommended fractional quantity makes value_i' = weight * total with leftover 0.
      qty_delta = (target_value - values[ticker]) / prices[ticker]
      next if qty_delta.zero?

      side = qty_delta.positive? ? :buy : :sell
      RebalancePlan::Instruction.new(ticker: ticker, side: side, quantity: qty_delta.abs)
    end

    RebalancePlan.new(instructions)
  end

  private

  def register!(stock)
    existing = @registry[stock.ticker]
    raise DomainError::DuplicateTicker if existing && !existing.equal?(stock)

    @registry[stock.ticker] = stock
  end

  def coerce_rational(value, error:)
    raise error unless value.is_a?(Numeric)

    value.is_a?(Float) ? Rational(value.to_s) : value.to_r
  end
end
