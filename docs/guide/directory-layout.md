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

## Concerns

Use a concern to group the code for one feature, when it could be shared with other classes or you may want to remove it all at once later. Name the concern after what it does.

Put a shared concern in `app/models/concerns/` or `app/controllers/concerns/`. If only one class uses the code, write it in a `concerning` block in that class instead. It stays grouped and easy to remove, without a separate file.

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

Gem setup is a good fit for a concern. Put every `include`, callback and helper a gem adds to a base class in one concern, then include that concern in the base class. All of the gem's setup is then in one file. To remove the gem, delete the file and the line that includes it.

For [Pundit](../gems/pundit/), put `Pundit::Authorization` and its `verify_authorized` check in a `PunditAuthorization` concern, in `app/controllers/concerns/pundit_authorization.rb`. Name the concern after the gem's own module, so it is easy to find.

```ruby
module PunditAuthorization
  extend ActiveSupport::Concern

  included do
    include Pundit::Authorization

    after_action :verify_authorized, unless: :devise_controller?
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
