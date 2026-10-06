---
title: Directory Layout
parent: The Guide
nav_order: 2
---

# Directory Layout

What lives where under `app/`, `config/` and `lib/`.

## The app directory

> **TODO:** Describe how you handle this.

## Extra directories

> **TODO:** Describe how you handle this.

## Namespaced classes

Define a class in a namespace inside a `module` block, e.g. `module Posts` and then `class CommentsController`. Don't use the short form, `class Posts::CommentsController`. Inside the block, Ruby looks up constants in `Posts` first, so the class can refer to its neighbours by their short names, e.g. `BaseController`. The short form skips `Posts`, so the same reference fails or finds a different class. Enable RuboCop's `Style/ClassAndModuleChildren` to check it. See [Tooling and CI: Nested modules](../tooling/#nested-modules).

```ruby
module Posts
  class CommentsController < BaseController
    # ...
  end
end
```

Use the full name everywhere outside the namespace, e.g. `Posts::CommentsController` in a spec or a route.

## Concerns

Use a concern to group the code for one feature, when it could be shared with other classes or you may want to remove it all at once later. Name the concern after what it does.

Put a shared concern in the `concerns/` directory of the classes that include it, e.g. `app/models/concerns/`, `app/controllers/concerns/`, `app/forms/concerns/` or `app/actions/concerns/`. Rails loads every `app/*/concerns/` directory as a root, so a concern there has no `Concerns::` namespace, e.g. `ValidatedCallable` in `app/actions/concerns/validated_callable.rb`. If only one class uses the code, write it in a `concerning` block in that class instead. It stays grouped and easy to remove, without a separate file.

```ruby
class Post < ApplicationRecord
  concerning :Publishing do
    included do
      scope :published, -> { where.not(published_at: nil) }
    end

    def publish
      update(published_at: Time.current)
    end
  end
end
```

### Gem setup

Gem setup is a good fit for a concern. Put every `include`, callback, error handler and helper a gem adds to a base class in one concern, then include that concern in the base class. All of the gem's setup is then in one file. To remove the gem, delete the file and the line that includes it.

For [Pundit](../gems/pundit/), put `Pundit::Authorization`, its `verify_authorized` check and the `rescue_from` for `Pundit::NotAuthorizedError` in a `PunditAuthorization` concern, in `app/controllers/concerns/pundit_authorization.rb`. Name the concern after the gem's own module, so it is easy to find.

```ruby
module PunditAuthorization
  extend ActiveSupport::Concern

  included do
    include Pundit::Authorization

    after_action :verify_authorized,
      unless: :devise_controller?

    rescue_from Pundit::NotAuthorizedError,
      with: :handle_not_authorized
  end

  private

  def handle_not_authorized
    redirect_to root_url,
      alert: "You are not authorized to perform this action."
  end
end
```

```ruby
class ApplicationController < ActionController::Base
  include PunditAuthorization

  before_action :authenticate_user!
end
```

## lib and config

> **TODO:** Describe how you handle this.

## Testing

> **TODO:** Describe how you handle this.
