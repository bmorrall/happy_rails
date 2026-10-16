# Turbo setup

Rules: `.github/instructions/happy_rspec_turbo.instructions.md`

- Use the `test` adapter for Action Cable in the test environment, with `adapter: test` under `test:` in `config/cable.yml`.
- Add the `have_broadcasted_*_to` matchers to action specs and `wait_for_turbo` to feature specs, in `spec/support/turbo.rb`. Copy `assets/spec/support/turbo.rb`.
