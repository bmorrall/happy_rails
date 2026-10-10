# ViewComponent setup

Rules: `.github/instructions/happy_view_component.instructions.md`

- Give specs in `spec/components/` a `:component` type, and include `ViewComponent::TestHelpers` and the route helpers in component specs, in `spec/support/view_component.rb`. Copy `assets/spec/support/view_component.rb`.
- Include `Capybara::RSpecMatchers` in component specs by adding `config.include Capybara::RSpecMatchers, type: :component` to `spec/support/capybara.rb`, never to `spec/support/view_component.rb`.
