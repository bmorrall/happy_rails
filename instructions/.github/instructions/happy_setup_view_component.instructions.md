---
applyTo: "spec/support/view_component.rb,spec/support/capybara.rb"
---

# ViewComponent setup

- Give specs in `spec/components/` a `:component` type in `spec/support/view_component.rb` with `config.define_derived_metadata(file_path: %r{/spec/components/}) { |metadata| metadata[:type] ||= :component }`.
- Include `ViewComponent::TestHelpers` in component specs in `spec/support/view_component.rb`, e.g. `config.include ViewComponent::TestHelpers, type: :component`.
- Include the route helpers in component specs in `spec/support/view_component.rb`, e.g. `config.include Rails.application.routes.url_helpers, type: :component`.
- Include `Capybara::RSpecMatchers` in component specs by adding `config.include Capybara::RSpecMatchers, type: :component` to `spec/support/capybara.rb`, never to `spec/support/view_component.rb`.
