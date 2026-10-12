module UserAccessSpecHelpers
  extend RSpec::Matchers::DSL

  matcher :grant_user_access do |user, as:|
    match do |actual|
      read_access(actual, user, as)
      @results.all? { |result| result[:method] && result[:scope] }
    end

    match_when_negated do |actual|
      read_access(actual, user, as)
      @results.none? { |result| result[:method] || result[:scope] }
    end

    failure_message do
      "expected #{as} access to every record, but:\n#{describe_results(as)}"
    end

    failure_message_when_negated do
      "expected no #{as} access to any record, but:\n#{describe_results(as)}"
    end

    private

    def read_access(actual, user, role)
      records = Array(actual)
      scope_ids = records.first.class.public_send(:"for_user_as_#{role}", user).where(id: records).pluck(:id)

      @results = records.map do |record|
        {
          record: record,
          method: record.public_send(:"user_is_#{role}?", user),
          scope: scope_ids.include?(record.id)
        }
      end
    end

    def describe_results(role)
      @results.map do |result|
        "  #{result[:record].inspect}: user_is_#{role}? returned #{result[:method]}, " \
          "for_user_as_#{role} #{result[:scope] ? "included" : "left out"} it"
      end.join("\n")
    end
  end
end

RSpec.configure do |config|
  config.include UserAccessSpecHelpers, type: :model
end
