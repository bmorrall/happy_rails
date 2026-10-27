module ActiveJobFeatureSpecHelpers
  def perform_all_enqueued_jobs(max_rounds: 10)
    expect(due_enqueued_jobs).not_to be_empty, "expected jobs to be due, but none are"

    max_rounds.times do
      perform_enqueued_jobs(at: Time.zone.now)
      return if due_enqueued_jobs.empty?
    end

    raise "jobs are still due after #{max_rounds} rounds: #{due_enqueued_jobs.map { |job| job[:job] }.uniq.join(", ")}"
  end

  private

  def due_enqueued_jobs
    enqueued_jobs.select { |job| job[:at].nil? || job[:at] <= Time.zone.now.to_f }
  end
end

RSpec.configure do |config|
  config.include ActiveJob::TestHelper, type: :job
  config.include ActiveJob::TestHelper, type: :feature
  config.include ActiveJobFeatureSpecHelpers, type: :feature
end
