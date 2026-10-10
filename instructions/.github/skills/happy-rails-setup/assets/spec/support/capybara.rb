RSpec.configure do |config|
  config.include Capybara::RSpecMatchers, type: :request
  config.include Capybara::RSpecMatchers, type: :feature
end
