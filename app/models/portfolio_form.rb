# Coordinates a submitted rebalance request: parses raw request params into
# typed positions, coerces each field with its own field-specific DomainError
# (so an invalid price never gets reported as an invalid quantity), and builds
# the Portfolio the controller renders. The controller itself only coordinates.
class PortfolioForm
  DEFAULT_POSITIONS = [
    { ticker: "META", quantity: "50", price: "10", target: "40" },
    { ticker: "APPL", quantity: "50", price: "10", target: "60" }
  ].freeze

  attr_reader :positions

  def initialize(params)
    @positions = extract_positions(params)
  end

  def build_portfolio
    portfolio = Portfolio.new
    weights = {}

    positions.each do |position|
      stock = Stock.new(position[:ticker])
      stock.current_price(coerce(position[:price], DomainError::InvalidPrice))
      portfolio.hold(stock, coerce(position[:quantity], DomainError::InvalidQuantity))
      weights[stock] = coerce(position[:target], DomainError::InvalidAllocation)
    end

    portfolio.allocate(weights)
    portfolio
  end

  private

  def extract_positions(params)
    return DEFAULT_POSITIONS unless params[:positions].present?

    permitted = params.expect(positions: [ [ :ticker, :quantity, :price, :target ] ])
    permitted.map { |entry| entry.to_h.symbolize_keys }
  end

  def coerce(value, error_class)
    return value if value.is_a?(Numeric)

    str = value.to_s.strip
    raise error_class if str.empty?

    str.match?(/\A[+-]?\d+\z/) ? Integer(str) : Float(str)
  rescue ArgumentError, TypeError, FloatDomainError
    raise error_class
  end
end
