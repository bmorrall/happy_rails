---
title: Validators
parent: The Guide
nav_order: 4
---

# Validators

How custom validators are written and used.

Put custom validators in `app/validators/`, e.g. `UnmodifiedValidator` in `app/validators/unmodified_validator.rb`. Rails loads them from there, and any model, form or action can use them.

## When to write a validator

> **TODO:** Describe how you handle this.

## Naming and layout

> **TODO:** Describe how you handle this.

## UnmodifiedValidator

`UnmodifiedValidator` checks that a record has no unsaved changes. Use it in an action that includes `ValidatedCallable`, on each record argument, e.g. `validates :post, unmodified: true`. It catches a caller that passes a record with unsaved changes, which the guide never allows. See [Actions: Arguments](../actions/#arguments) and [Actions: Checking arguments](../actions/#checking-arguments).

```ruby
class UnmodifiedValidator < ActiveModel::EachValidator
  def validate_each(action, attribute, record)
    return unless record.respond_to?(:has_changes_to_save?) && record.has_changes_to_save?

    action.errors.add(attribute, :modified, message: options[:message] || "has unsaved changes")
  end
end
```

Add the error with a symbol, `:modified`, so code and specs can check which error it is, e.g. `errors.of_kind?(:post, :modified)`. Give it a default message, "has unsaved changes". A caller can pass its own, e.g. `unmodified: { message: "is being edited" }`.

Unmodified means no unsaved changes at all, whether the record is saved or not. A new record built with values, e.g. `Post.new(title:)`, has changes to save, so it fails the check. It skips values that aren't records, e.g. `nil`, so pair it with `presence: true` when the argument is required.

```ruby
module Posts
  class PublishPost < ApplicationAction
    include ValidatedCallable

    validates :post, :publisher, presence: true, unmodified: true

    # ...
  end
end
```

A failed check is a bug in the caller, so never rescue it. See [Actions: Checking arguments](../actions/#checking-arguments).

## Testing

> **TODO:** Describe how you handle this.
