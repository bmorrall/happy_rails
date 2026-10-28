module FormSpecHelpers
  def have_field_error(message)
    have_css(".invalid-feedback", text: message)
  end

  def have_form_error(message)
    have_css("form .alert-danger", text: message)
  end
end

RSpec.configure do |config|
  config.include FormSpecHelpers, type: :request
  config.include FormSpecHelpers, type: :feature
end
