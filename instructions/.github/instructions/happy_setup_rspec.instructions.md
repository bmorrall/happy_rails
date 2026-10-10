---
applyTo: "spec/rails_helper.rb,spec/support/time_helpers.rb,spec/support/capybara.rb,spec/support/forms.rb"
---

# RSpec and FactoryBot setup

- Load every file in `spec/support` from `spec/rails_helper.rb` by uncommenting the generated line, e.g. `Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }`.
- Include `ActiveSupport::Testing::TimeHelpers` for every spec in `spec/support/time_helpers.rb`, e.g. `config.include ActiveSupport::Testing::TimeHelpers`.
- Include `Capybara::RSpecMatchers` for request and feature specs in `spec/support/capybara.rb`, e.g. `config.include Capybara::RSpecMatchers, type: :request`, so request specs can check the response HTML with Capybara matchers. When a gem's specs check HTML too, add its spec type to the same file, e.g. `config.include Capybara::RSpecMatchers, type: :component`.
- Give specs in `spec/forms/` a `:form` type in `spec/support/forms.rb` with `config.define_derived_metadata(file_path: %r{/spec/forms/}) { |metadata| metadata[:type] ||= :form }`.
