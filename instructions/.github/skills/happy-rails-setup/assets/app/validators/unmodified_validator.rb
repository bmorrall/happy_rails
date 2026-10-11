class UnmodifiedValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value&.has_changes_to_save? == false

    record.errors.add(attribute, :modified, **options)
  end
end
