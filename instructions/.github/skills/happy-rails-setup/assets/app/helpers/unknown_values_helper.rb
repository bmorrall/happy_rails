module UnknownValuesHelper
  def unknown_value_tag
    tag.span("—", class: "text-muted", aria: { label: "Unknown" })
  end
end
