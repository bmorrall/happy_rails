module PunditPolicies
  extend ActiveSupport::Concern

  private

  def policy(class_or_resource)
    Pundit.policy!(current_user, class_or_resource)
  end

  def policy_scope(scope)
    Pundit.policy_scope!(current_user, scope)
  end
end
