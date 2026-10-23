# dry-rb setup

Rules: `.github/instructions/happy_dry_rb.instructions.md`

- Define the app's `Types` module in `lib/types.rb`, which includes `Dry.Types()`. Copy `assets/lib/types.rb`. Rails autoloads it when `config/application.rb` calls `config.autoload_lib`. If it does not, add `config.autoload_lib(ignore: %w[assets tasks])`.
