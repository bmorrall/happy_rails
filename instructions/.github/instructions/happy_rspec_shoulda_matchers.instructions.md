---
applyTo: "spec/models/**/*.rb,spec/forms/**/*.rb"
---

# Shoulda Matchers

- Test validations with Shoulda Matchers `allow_value`, asserting that a value is allowed or rejected, e.g. `is_expected.to allow_value("A title").for(:title)`. Never assert `valid?` or `invalid?` to test a validation.
- Assert the error message as a string for every rejected value with `with_message`, e.g. `is_expected.not_to allow_value("").for(:title).with_message("can't be blank")`.
- Use the same matchers for validations on form objects, e.g. in `spec/forms/create_post_form_spec.rb`.
- Test each association with its Shoulda Matchers matcher, e.g. `belong_to`, `have_one` or `have_many`, with a qualifier for each option the association declares, e.g. `is_expected.to belong_to(:author).class_name("User")` and `is_expected.to have_many(:comments).dependent(:destroy)`.
