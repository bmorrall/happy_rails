module FlashSpecHelpers
  extend RSpec::Matchers::DSL

  FLASH_KEYS = %w[notice alert].freeze

  FLASH_KEYS.each do |key|
    matcher :"have_flash_#{key}" do |message|
      match { |flash| values_match?({ key => message }, flash.to_hash) }
      failure_message { |flash| "expected the flash to be #{{ key => message }}, but it was #{flash.to_hash}" }
    end
  end
end

RSpec.configure do |config|
  config.include FlashSpecHelpers, type: :request
end
