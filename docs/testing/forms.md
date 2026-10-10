---
title: Forms
parent: Testing
nav_order: 5
---

# Forms

How I test form objects.

For the code itself, see [Forms](../../guide/forms/).

## Collections

Cover every `collection_for_<attribute>` method with a unit test, in `spec/forms/`. The form's select and its validation both use the collection. A wrong collection hides a choice from the user, or rejects a value the user is allowed to pick.

```ruby
RSpec.describe CreatePostForm do
  describe "#collection_for_status" do
    it "returns every post status" do
      form = described_class.new(Post.new, build(:user))

      expect(form.collection_for_status).to eq(["draft", "published"])
    end
  end
end
```

## Custom validators

Test a form attribute that uses a custom validator with the validator's matcher, as in a model spec, e.g. `it { is_expected.to validate_isbn_of(:isbn) }`. See [Validators: Models and forms that use a validator](../validators/#models-and-forms-that-use-a-validator).
