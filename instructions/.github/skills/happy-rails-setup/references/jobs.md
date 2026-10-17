# Jobs setup

Rules: `.github/instructions/happy_jobs.instructions.md`, `.github/instructions/happy_rspec_jobs.instructions.md`

- Put emails sent with `deliver_later` on the `mailers` queue: set `config.action_mailer.deliver_later_queue_name = :mailers` in `config/application.rb`.
- Include `ActiveJob::TestHelper` in job specs and feature specs in `spec/support/active_job.rb`. Copy `assets/spec/support/active_job.rb`.
