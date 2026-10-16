---
applyTo: "spec/forms/**/*.rb"
---

# Form specs

- Cover every `collection_for_<attribute>` method with a unit test in `spec/forms/`, e.g. `describe "#collection_for_category"` in `spec/forms/create_post_form_spec.rb`.
- In form specs, test an attribute that uses a custom validator with the validator's matcher, e.g. `it { is_expected.to validate_isbn_format_of(:isbn) }`. You MUST NOT repeat the cases from the validator's own spec.
