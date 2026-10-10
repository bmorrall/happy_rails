class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Attributes::Normalization
  include ActiveModel::Validations::Callbacks

  def initialize(current_user, params = {})
    @current_user = current_user
    super(params)
  end

  private

  attr_reader :current_user
end
