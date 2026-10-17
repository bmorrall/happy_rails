---
applyTo: "spec/models/**/*.rb,spec/forms/**/*.rb"
---

# Shoulda Matchers

- Test a validation that Shoulda Matchers has a matcher for with that matcher, written as a one-liner, e.g. `it { is_expected.to validate_presence_of(:title).with_message("can't be blank") }`, `it { is_expected.to validate_length_of(:title).is_at_most(Post::TITLE_MAX_LENGTH).with_message("is too long (maximum is 100 characters)") }` or `it { is_expected.to validate_numericality_of(:word_count).is_greater_than(0).with_message("must be greater than 0") }`. This includes validators that compare two attributes, e.g. `validate_comparison_of(:ends_at).is_greater_than(:starts_at)`.
- Test uniqueness with `validate_uniqueness_of`, after creating an existing record with a factory, e.g. `create(:post)` then `expect(post).to validate_uniqueness_of(:slug).with_message("has already been taken")`. Add `.case_insensitive` only when the validation sets `case_sensitive: false`, and `.ignoring_case_sensitivity` only when the model changes the value's case itself, e.g. with a `normalizes` that downcases it.
- When no matcher covers a validation, or it is too complex for its matcher, e.g. a format, a custom rule or a uniqueness rule scoped through another model, test the values it accepts and rejects with `allow_value`, e.g. `is_expected.not_to allow_value("My Post").for(:slug).with_message("is invalid")` and `expect(post).not_to allow_value(existing_post.slug).for(:slug).with_message("has already been taken")`. Create any records the rule checks against with a factory first, e.g. `existing_post = create(:post)`.
- Assert the error message as a string with `with_message` for every value `allow_value` rejects, e.g. `is_expected.not_to allow_value("").for(:title).with_message("can't be blank")`. A `validate_*` matcher SHOULD have `with_message` too, e.g. `it { is_expected.to validate_presence_of(:title).with_message("can't be blank") }`.
- You MUST NOT assert `valid?`, `invalid?` or `be_valid` to test a validation.
- Use the same matchers for validations on form objects, e.g. in `spec/forms/create_post_form_spec.rb`.
- Test each association with its Shoulda Matchers matcher, e.g. `belong_to`, `have_one` or `have_many`, with a qualifier for each option the association declares, e.g. `is_expected.to belong_to(:author).class_name("User")` and `is_expected.to have_many(:comments).dependent(:destroy)`.
