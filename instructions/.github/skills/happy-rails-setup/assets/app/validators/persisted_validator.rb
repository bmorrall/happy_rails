class PersistedValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value&.persisted?

    record.errors.add(attribute, :not_persisted, **options)
  end
end
