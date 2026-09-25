class PortfoliosController < ApplicationController
  DEFAULT_POSITIONS = [
    { ticker: "META", quantity: "50", price: "10", target: "40" },
    { ticker: "APPL", quantity: "50", price: "10", target: "60" }
  ].freeze

  def show
    @positions = DEFAULT_POSITIONS
  end

  def rebalance
    @positions = submitted_positions
    portfolio = build_portfolio(@positions)
    @plan = portfolio.rebalance
    @holdings = portfolio.holdings
    render :show
  rescue DomainError => error
    @error = error.class.name.demodulize.underscore.humanize
    @plan = nil
    @holdings = nil
    render :show
  end

  private

  def submitted_positions
    raw = params[:positions]
    return DEFAULT_POSITIONS if raw.blank?

    entries = raw.is_a?(Array) ? raw : raw.values
    entries.map do |entry|
      data = entry.respond_to?(:permit) ? entry.permit(:ticker, :quantity, :price, :target) : entry
      {
        ticker: data[:ticker] || data["ticker"],
        quantity: data[:quantity] || data["quantity"],
        price: data[:price] || data["price"],
        target: data[:target] || data["target"]
      }
    end
  end

  def build_portfolio(positions)
    portfolio = Portfolio.new
    weights = {}

    positions.each do |position|
      stock = Stock.new(position[:ticker])
      stock.current_price(to_numeric(position[:price]))
      portfolio.hold(stock, to_numeric(position[:quantity]))
      weights[stock] = to_numeric(position[:target])
    end

    portfolio.allocate(weights)
    portfolio
  end

  def to_numeric(value)
    return value if value.is_a?(Numeric)

    str = value.to_s.strip
    raise DomainError::InvalidQuantity if str.empty?

    str.match?(/\A[+-]?\d+\z/) ? Integer(str) : Float(str)
  rescue ArgumentError, TypeError, FloatDomainError
    raise DomainError::InvalidQuantity
  end
end
