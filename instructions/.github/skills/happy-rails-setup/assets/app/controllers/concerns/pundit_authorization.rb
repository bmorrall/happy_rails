module PunditAuthorization
  extend ActiveSupport::Concern

  included do
    include Pundit::Authorization

    after_action :verify_authorized,
      unless: :devise_controller?
    after_action :verify_policy_scoped,
      only: :index

    rescue_from Pundit::NotAuthorizedError,
      with: :handle_not_authorized_error
  end

  private

  def handle_not_authorized_error
    redirect_to after_not_authorized_error_path,
      alert: "You are not authorized to perform this action."
  end

  def after_not_authorized_error_path
    root_path
  end
end
