RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/forms/}) do |metadata|
    metadata[:type] ||= :form
  end
end
