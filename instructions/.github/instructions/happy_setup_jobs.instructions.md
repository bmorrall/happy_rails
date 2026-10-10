---
applyTo: "spec/support/active_job.rb"
---

# Jobs setup

- Include `ActiveJob::TestHelper` in job specs in `spec/support/active_job.rb`, e.g. `config.include ActiveJob::TestHelper, type: :job`.
- Include `ActiveJob::TestHelper` in feature specs in `spec/support/active_job.rb`, e.g. `config.include ActiveJob::TestHelper, type: :feature`.
