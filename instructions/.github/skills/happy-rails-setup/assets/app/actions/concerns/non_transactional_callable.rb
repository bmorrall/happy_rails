module NonTransactionalCallable
  extend ActiveSupport::Concern

  class_methods do
    def call(...)
      if ActiveRecord::Base.connection.current_transaction.joinable?
        raise "#{name} calls another service, so it can't run inside a transaction"
      end

      super
    end
  end
end
