module TurboSpecHelpers
  %i[append prepend replace update remove before after refresh].each do |action|
    define_method(:"have_broadcasted_#{action}_to") do |*streamables, target: nil|
      have_broadcasted_action_to(action, *streamables, target:)
    end
  end

  def have_broadcasted_action_to(action, *streamables, target: nil)
    attributes = [%(action="#{action}")]
    attributes << %(target="#{target.is_a?(String) ? target : dom_id(target)}") if target

    have_broadcasted_to(turbo_stream_name(streamables)).with(a_string_including(*attributes))
  end

  private

  def turbo_stream_name(streamables)
    streamables.map { |streamable| streamable.try(:to_gid_param) || streamable.to_s }.join(":")
  end
end

module TurboFeatureSpecHelpers
  def wait_for_turbo
    page.document.synchronize do
      next if page.evaluate_script("window.Turbo !== undefined")

      raise Capybara::ExpectationNotMet, "Turbo has not started on the page"
    end

    expect(page).to have_no_css("turbo-cable-stream-source:not([connected])", visible: :all)
  end
end

RSpec.configure do |config|
  config.include TurboSpecHelpers, type: :action
  config.include TurboFeatureSpecHelpers, type: :feature
end
