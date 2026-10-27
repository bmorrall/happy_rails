module ActiveJobFeatureSpecHelpers
  def perform_all_enqueued_jobs(max_rounds: 10)
    expect(enqueued_jobs).not_to be_empty, "expected jobs to be enqueued, but the queue is empty"

    max_rounds.times do
      perform_enqueued_jobs
      return if enqueued_jobs.empty?
    end

    raise "jobs are still enqueued after #{max_rounds} rounds: #{enqueued_jobs.map { |job| job[:job] }.uniq.join(", ")}"
  end
end

RSpec.configure do |config|
  config.include ActiveJob::TestHelper, type: :job
  config.include ActiveJob::TestHelper, type: :feature
  config.include ActiveJobFeatureSpecHelpers, type: :feature
end
