class ApplicationDecorator < Draper::Decorator
  ### Policy ###

  delegate :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?,
    to: :policy,
    prefix: :can

  private

  def policy
    @policy ||= h.policy(object)
  end
end
