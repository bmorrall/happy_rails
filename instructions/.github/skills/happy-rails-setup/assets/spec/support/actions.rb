RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/actions/}) do |metadata|
    metadata[:type] ||= :action
  end
end
