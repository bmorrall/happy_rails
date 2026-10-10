class NilDecorator
  include Draper::ViewHelpers

  def self.for(klass)
    new(klass.new.decorate)
  end

  def initialize(decorator)
    @decorator = decorator
  end

  def present?
    false
  end

  def blank?
    true
  end

  def presence
    nil
  end

  def method_missing(name, *args, &block)
    if !@decorator.respond_to?(name)
      super
    elsif name.start_with?("can_") && name.end_with?("?")
      false
    else
      h.unknown_value_tag
    end
  end

  def respond_to_missing?(name, include_private = false)
    @decorator.respond_to?(name, include_private) || super
  end
end
