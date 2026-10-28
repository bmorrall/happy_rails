module FormatSpecHelpers
  def format_text(value)
    value.presence || raise(ArgumentError, "expected a value to check, got #{value.inspect}")
  end

  def format_date(value)
    I18n.l(value.to_date, format: :long)
  end

  def format_datetime(value)
    I18n.l(value, format: :long)
  end
end

RSpec.configure do |config|
  config.include FormatSpecHelpers, type: :request
  config.include FormatSpecHelpers, type: :feature
end
