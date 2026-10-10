module PunditAuthorization
  extend ActiveSupport::Concern

  included do
    include Pundit::Authorization

    after_action :verify_authorized,
      unless: :devise_controller?

    rescue_from Pundit::NotAuthorizedError,
      with: :handle_not_authorized_error
  end

  private

  def handle_not_authorized_error
    redirect_to root_url,
      alert: "You are not authorized to perform this action."
  end
end
