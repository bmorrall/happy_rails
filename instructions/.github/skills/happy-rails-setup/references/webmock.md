# WebMock and VCR setup

Rules: `.github/instructions/happy_rspec_webmock.instructions.md`

- Load WebMock and allow requests to localhost in `spec/support/webmock.rb`, so `:js` feature specs can reach the browser and the app's server. Copy `assets/spec/support/webmock.rb`. If the app already loads WebMock elsewhere, e.g. in `spec/rails_helper.rb`, add `allow_localhost: true` to its `disable_net_connect!` call instead.
- When the app uses `vcr`, add `config.ignore_localhost = true` to its `VCR.configure` block.
