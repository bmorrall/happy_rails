class UnmodifiedValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return record.errors.add(attribute, :invalid, **options) unless value.respond_to?(:has_changes_to_save?)
    return unless value.has_changes_to_save?

    record.errors.add(attribute, :modified, **options)
  end
end
