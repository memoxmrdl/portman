class PortfoliosController < ApplicationController
  def show
    @positions = PortfolioForm::DEFAULT_POSITIONS
  end

  def rebalance
    form = PortfolioForm.new(params)
    @positions = form.positions
    portfolio = form.build_portfolio
    @plan = portfolio.rebalance
    @holdings = portfolio.holdings
    render :show
  rescue DomainError => error
    @error = domain_error_message(error)
    @plan = nil
    @holdings = nil
    render :show
  end

  private

  def domain_error_message(error)
    key = error.class.name.demodulize.underscore
    I18n.t(key, scope: :domain_errors, default: I18n.t(:default, scope: :domain_errors))
  end
end
