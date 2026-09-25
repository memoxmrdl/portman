class RebalancePlan
  Instruction = Data.define(:ticker, :side, :quantity)

  attr_reader :instructions

  def initialize(instructions)
    @instructions = instructions.sort_by(&:ticker).freeze
    freeze
  end

  def empty?
    instructions.empty?
  end
end
