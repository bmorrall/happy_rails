# RSpec and FactoryBot setup

Rules: `.github/instructions/happy_rspec.instructions.md`, `.github/instructions/happy_rspec_models.instructions.md`

- Load every file in `spec/support` from `spec/rails_helper.rb` by uncommenting the generated line, e.g. `Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }`.
- Include `ActiveSupport::Testing::TimeHelpers` for every spec in `spec/support/time_helpers.rb`. Copy `assets/spec/support/time_helpers.rb`.
- Include `ActionView::RecordIdentifier` for every spec in `spec/support/record_identifier.rb`, so specs can call `dom_id`. Copy `assets/spec/support/record_identifier.rb`.
- Include `Capybara::RSpecMatchers` for request and feature specs in `spec/support/capybara.rb`, so request specs can check the response HTML with Capybara matchers. Copy `assets/spec/support/capybara.rb`. When a gem's specs check HTML too, add its spec type to the same file, e.g. `config.include Capybara::RSpecMatchers, type: :component`.
- When the app has the `faker` gem, seed Faker with RSpec's seed and clear its `unique` values after each example in `spec/support/faker.rb`. Copy `assets/spec/support/faker.rb`.
- Add a `have_flash_<key>` matcher for each flash key in a `FlashSpecHelpers` module in `spec/support/flash_spec_helpers.rb`, included for `type: :request`. Copy `assets/spec/support/flash_spec_helpers.rb`, and list every key the app's controllers use in `FLASH_KEYS`, e.g. `%w[notice alert success error]` for an app with `add_flash_types :success, :error`.
- Give specs in `spec/forms/` a `:form` type in `spec/support/forms.rb`. Copy `assets/spec/support/forms.rb`.
- Give specs in `spec/actions/` an `:action` type in `spec/support/actions.rb`. Copy `assets/spec/support/actions.rb`.
- When a model has a `concerning :UserAccess` block, add the `grant_user_access` matcher in a `UserAccessSpecHelpers` module in `spec/support/user_access_spec_helpers.rb`, included for `type: :model`. Copy `assets/spec/support/user_access_spec_helpers.rb`.
