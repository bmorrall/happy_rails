module HoneybadgerCauseContext
  extend ActiveSupport::Concern

  def to_honeybadger_context
    cause.respond_to?(:to_honeybadger_context) ? cause.to_honeybadger_context : {}
  end
end
