module ValidatedCallable
  extend ActiveSupport::Concern

  include ActiveModel::Validations

  class_methods do
    def call(...)
      action = new(...)
      action.validate!
      action.call
      nil
    end
  end
end
