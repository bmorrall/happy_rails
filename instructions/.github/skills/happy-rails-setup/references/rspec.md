# RSpec and FactoryBot setup

Rules: `.github/instructions/happy_rspec.instructions.md`

- Load every file in `spec/support` from `spec/rails_helper.rb` by uncommenting the generated line, e.g. `Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }`.
- Include `ActiveSupport::Testing::TimeHelpers` for every spec in `spec/support/time_helpers.rb`. Copy `assets/spec/support/time_helpers.rb`.
- Include `Capybara::RSpecMatchers` for request and feature specs in `spec/support/capybara.rb`, so request specs can check the response HTML with Capybara matchers. Copy `assets/spec/support/capybara.rb`. When a gem's specs check HTML too, add its spec type to the same file, e.g. `config.include Capybara::RSpecMatchers, type: :component`.
- Give specs in `spec/forms/` a `:form` type in `spec/support/forms.rb`. Copy `assets/spec/support/forms.rb`.
