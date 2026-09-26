class Stock
  attr_reader :ticker, :last_available_price

  def initialize(ticker)
    raise DomainError::InvalidTicker if ticker.nil? || !ticker.is_a?(String) || ticker.strip.empty?

    # Ticker is opaque: store exactly as given; never rewrite APPL → AAPL.
    @ticker = ticker
    @last_available_price = nil
  end

  def current_price(last_available_price = nil)
    @last_available_price = coerce_positive_rational!(last_available_price)
  end

  def priced?
    last_available_price.is_a?(Rational) && last_available_price.positive?
  end

  private

  def coerce_positive_rational!(value)
    raise DomainError::InvalidPrice if value.nil?
    raise DomainError::InvalidPrice if value.is_a?(String) && value.strip.empty?
    raise DomainError::InvalidPrice unless value.is_a?(Numeric)

    rational = ExactNumber.from(value)
    raise DomainError::InvalidPrice unless rational.positive?

    rational
  rescue ArgumentError, TypeError, FloatDomainError
    raise DomainError::InvalidPrice
  end
end
