---
title: Records from a Legacy Database
parent: Patterns
nav_order: 7
---

# Records from a Legacy Database

How to find a record that might still be in an older database, and bring it over when it is.

When an app replaces an older system, some records stay in the old database until someone needs them. The publishing app replaced an older system, and a user who hasn't been back since is only in its database, as a `LegacyUser`. When the app looks a user up by email, e.g. to add a Co-author, it looks in its own `users` table first. If the user isn't there, it looks in the legacy database, and copies the user over.

Several callers need this lookup, so the code is shared. It creates a record, so it can't go in a [service](../../guide/services/#kinds-of-services), which never saves the app's models. It can't return the record either, because [actions return nothing](../../guide/actions/#return-values). These patterns work within both rules.

The legacy records connect to their own database through an abstract base class.

```ruby
class LegacyRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :legacy, reading: :legacy }
end
```

```ruby
class LegacyUser < LegacyRecord
  self.table_name = "users"
end
```

## Fill a record the caller builds

The caller builds the record it's looking for, and passes it to an action. When the record is already saved, the action does nothing. When it's new, the action fills it from the legacy record and saves it. The caller already holds the record, so nothing has to come back from the action.

```ruby
module Users
  class ImportLegacyUser < ApplicationAction
    def initialize(user)
      @user = user
    end

    def call
      return if user.persisted?

      legacy_user = LegacyUser.find_by(email: user.email)
      return if legacy_user.nil?

      user.update!(name: legacy_user.full_name)
    end

    private

    attr_reader :user
  end
end
```

```ruby
user = User.find_or_initialize_by(email:)
Users::ImportLegacyUser.call(user)
```

After the call, `user.persisted?` says whether the user was found in either database. When the user is already in the app, the lookup takes one query, and the action returns straight away. When the user is only in the legacy database, it takes three: the app's lookup, the legacy lookup and the insert. The caller doesn't search again, because the record it holds is the one the action saved.

This is the guide's way to get a value from an action: save it on a record the caller holds. The action takes a record with unsaved changes, which [Actions: Arguments](../../guide/actions/#arguments) allows for an action whose task is to save a new record the caller built. Don't check its arguments with `unmodified:`, because the record is meant to be new.

When a caller carries on after the import fails, e.g. `Posts::AddCoauthors` skipping an email, the action needs its own `Error` and a savepoint. See [Actions: Carrying on when another action fails](../../guide/actions/#carrying-on-when-another-action-fails).

Two requests for the same user at once can both find no user, and both import one. Add a unique index on `users.email`, so the second insert raises `ActiveRecord::RecordNotUnique` instead of saving a copy. That's rare enough to let the request fail, and a retry finds the saved user.

## Raise when it's missing

When every caller treats a user who isn't in either database as an error, raise it in the action. `find_by!` raises `ActiveRecord::RecordNotFound`, as `User.find_by!` would. A controller already turns that into a 404, so a caller needs no check of its own.

```ruby
def call
  return if user.persisted?

  legacy_user = LegacyUser.find_by!(email: user.email)
  user.update!(name: legacy_user.full_name)
end
```

When some callers expect the user might be missing, e.g. a job that carries on without them, keep the check in those callers instead. They would otherwise rescue `RecordNotFound` to get on with their normal work, which uses an error for normal flow.

```ruby
user = User.find_or_initialize_by(email:)
Users::ImportLegacyUser.call(user)
user = nil unless user.persisted?
```

## More than one way to match

When the lookup is more than one `find_by`, e.g. a user's email or their secondary email, give each model a query method for it. It only reads, or builds a new record, so it belongs on the model. See [Models: Scopes and queries](../../guide/models/#scopes-and-queries).

```ruby
class User < ApplicationRecord
  def self.find_or_initialize_by_any_email(email)
    find_by(email:) || find_by(secondary_email: email) || new(email:)
  end
end
```

```ruby
class LegacyUser < LegacyRecord
  def self.find_by_any_email!(email)
    find_by(email:) || find_by!(secondary_email: email)
  end
end
```

The action calls the legacy method, and sets both emails from the legacy record. The email the caller searched by might be the legacy user's secondary email, so the new user's `email` is wrong until the action sets it.

```ruby
def call
  return if user.persisted?

  legacy_user = LegacyUser.find_by_any_email!(user.email)
  user.update!(
    email: legacy_user.email,
    secondary_email: legacy_user.secondary_email,
    name: legacy_user.full_name
  )
end
```

```ruby
user = User.find_or_initialize_by_any_email(email)
Users::ImportLegacyUser.call(user)
```

Look up the email first, then the secondary email. One `where(email:).or(where(secondary_email: email))` can match two users, one by each column, and `first` then picks either. Two lookups make the email win, and the usual case is still one query. When the rules for matching change, e.g. to ignore case, only the two query methods change.

A unique index on each column stops two users sharing an email. It can't stop one user's secondary email being another user's email. If that has to be impossible, validate it on `User`.

## Copy every record first

When you can, copy every legacy record over in a job, then point the callers at the app's own table. The lookup in the legacy database goes away, along with the action call in every caller.

```ruby
class ImportLegacyUsersJob < ApplicationJob
  def perform
    LegacyUser.find_each do |legacy_user|
      user = User.find_or_initialize_by_any_email(legacy_user.email)
      Users::ImportLegacyUser.call(user)
    end
  end
end
```

The job uses the same action, so a user it copies matches a user a caller would have copied. Keep the callers' lookup until the job has finished, then remove it.

## What to avoid

Don't return the user from the action, e.g. `user = Users::ImportLegacyUser.call(email:)`. Actions return nothing. See [Values from Actions](../values-from-actions/).

Don't search, import, then search again, e.g. call the action with an email, then `User.find_by(email:)` after it. It works, but every caller makes an extra query, and repeats the search. Pass the record the caller built instead.

Don't call the action from a model method, e.g. `User.find_or_import_by(email:)`. A model queries and changes its own records. The action is the one place that writes, and each caller calls it.
