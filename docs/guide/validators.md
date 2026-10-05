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

## Writing a validator

### Naming and layout

> **TODO:** Describe how you handle this.

### Blank values

Rails' own validators, other than `presence`, check a blank value like any other, e.g. `length: { minimum: 3 }` fails for `nil`. Pass `allow_blank: true` or `allow_nil: true` to skip blank values. A custom validator that inherits from `ActiveModel::EachValidator` gets both options for free. Rails checks them before it calls `validate_each`.

Write custom validators the same way. Never skip a blank value inside `validate_each`. Treat it like any other value that fails the check, and let the caller decide with `allow_blank` or `allow_nil`. Then every validator in the app handles blank values the same way.

When an attribute also has `presence: true`, add `allow_blank: true` to its other validators. A blank value then gets one error, "can't be blank", not a stack of errors that all say it's missing.

```ruby
validates :title, presence: true, length: { minimum: 3, allow_blank: true }
validates :post, presence: true, unmodified: { allow_blank: true }
```

## I18n

Add each error with a symbol, e.g. `:modified`, not a sentence. Rails uses the symbol to look up the message in the locale files, so you can change the wording, or translate it, without changing the validator.

### How Rails finds the message

For `errors.add(:post, :modified)` with no `message:`, Rails tries these keys in order, and uses the first one it finds:

1. `activemodel.errors.models.posts/publish_post.attributes.post.modified`, for this attribute of this class
2. `activemodel.errors.models.posts/publish_post.modified`, for any attribute of this class
3. `activemodel.errors.messages.modified`, for any Active Model class
4. `errors.attributes.post.modified`, for this attribute name in any class
5. `errors.messages.modified`, for everything

The first part of the first three keys is the class's I18n scope. It is `activemodel` for actions and forms, and `activerecord` for models. Each step is more general than the one before, so you set the default once in `errors.messages`, and override it only where one class or attribute needs different words.

If none of the keys exist, the message is a "Translation missing" note that lists every key Rails tried. It's useful when you set up a message, but a user should never see it.

### Default messages

When you pass `message:` as a string, Rails checks only the first key, for this attribute of this class. If that's missing, it uses your string, and skips the rest. That's why [`UnmodifiedValidator`](#unmodifiedvalidator) works with no locale files, but also why `errors.messages.modified` in a locale file would do nothing.

When the app uses I18n, move the default into the locale file, and pass `message:` only when the caller gives one.

```yaml
# config/locales/en.yml
en:
  errors:
    messages:
      example: "is not an example"
```

```ruby
class ExampleValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if example?(value)

    record.errors.add(attribute, :example, **options.slice(:message))
  end

  private

  def example?(value)
    # ...
  end
end
```

Then every key in [How Rails finds the message](#how-rails-finds-the-message) works, and a caller can still pass its own message, e.g. `example: { message: "isn't one of ours" }`.

## Common validators

Validators that most apps need. Add the ones you use to `app/validators/`.

### UnmodifiedValidator

`UnmodifiedValidator` checks that a record has no unsaved changes. Use it in an action that includes `ValidatedCallable`, on each record argument, e.g. `validates :post, presence: true, unmodified: { allow_blank: true }`. It catches a caller that passes a record with unsaved changes, which the guide never allows. See [Actions: Arguments](../actions/#arguments) and [Actions: Checking arguments](../actions/#checking-arguments).

```ruby
class UnmodifiedValidator < ActiveModel::EachValidator
  def validate_each(action, attribute, record)
    return unless record.respond_to?(:has_changes_to_save?) && record.has_changes_to_save?

    action.errors.add(attribute, :modified, message: options[:message] || "has unsaved changes")
  end
end
```

Add the error with a symbol, `:modified`, so code and specs can check which error it is, e.g. `errors.of_kind?(:post, :modified)`. Give it a default message, "has unsaved changes". A caller can pass its own, e.g. `unmodified: { message: "is being edited" }`.

Unmodified means no unsaved changes at all, whether the record is saved or not. A new record built with values, e.g. `Post.new(title:)`, has changes to save, so it fails the check. It only checks values that can have unsaved changes, so it adds no error for `nil`. Still add `allow_blank: true` next to `presence: true`, as for every validator. See [Blank values](#blank-values).

```ruby
module Posts
  class PublishPost < ApplicationAction
    include ValidatedCallable

    validates :post, :publisher, presence: true, unmodified: { allow_blank: true }

    # ...
  end
end
```

A failed check is a bug in the caller, so never rescue it. See [Actions: Checking arguments](../actions/#checking-arguments).

## Testing

> **TODO:** Describe how you handle this.
