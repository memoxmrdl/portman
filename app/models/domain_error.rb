class DomainError < StandardError
  class InvalidTicker < DomainError; end
  class InvalidPrice < DomainError; end
  class InvalidQuantity < DomainError; end
  class DuplicateTicker < DomainError; end
  class InvalidAllocation < DomainError; end
  class UnpricedInstrument < DomainError; end
  class NonPositiveTotal < DomainError; end
end
