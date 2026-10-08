---
title: Values from Services
parent: Patterns
nav_order: 6
---

# Values from Services

How to show a value read from another service, when [the controller reads it before the view renders](../../guide/controllers/#values-from-services).

Sometimes a page shows a value that lives in another service, e.g. the open rate of a post's newsletter. The controller reads it with a client, e.g. `NewsletterClient#fetch_stats`, and nothing changes, so no action is needed. See [Services: Calling a service](../../guide/services/#calling-a-service).

The value is either one value for the whole page, e.g. the open rate on `GET /posts/:id`, or one value for each record in a list, e.g. the open rate of each post on `GET /posts`. These patterns cover both.

## One value for the page

### Assign it in the action

Read the value in a private method, and assign it to an instance variable in the action. This is the simplest way, and it suits most pages.

```ruby
class PostsController < ApplicationController
  # GET /posts/:id
  def show
    @newsletter_stats = fetch_newsletter_stats
  end

  private

  def fetch_newsletter_stats
    NewsletterClient.new.fetch_stats(@post.newsletter_id) if @post.newsletter_id?
  end
end
```

```erb
<% if @newsletter_stats %>
  <p>Open rate: <%= number_to_percentage(@newsletter_stats.open_rate, precision: 1) %></p>
<% end %>
```

### Read it in a callback

When several actions show the same value, read it in a `set_` callback. The call is then listed at the top of the controller, with the actions that make it.

```ruby
class PostsController < ApplicationController
  before_action :set_newsletter_stats,
    only: %i[show edit]

  # ...

  private

  def set_newsletter_stats
    @newsletter_stats = NewsletterClient.new.fetch_stats(@post.newsletter_id) if @post.newsletter_id?
  end
end
```

### Give it to the view with a helper method

Add a helper method when a partial or a helper needs the value, so you don't have to pass it down. The helper method only returns the value the action read. It never calls the service.

```ruby
class PostsController < ApplicationController
  helper_method :newsletter_stats

  # GET /posts/:id
  def show
    @newsletter_stats = fetch_newsletter_stats
  end

  private

  attr_reader :newsletter_stats

  # ...
end
```

```erb
<%# app/views/posts/_newsletter_stats.html.erb %>
<% if newsletter_stats %>
  <p>Open rate: <%= number_to_percentage(newsletter_stats.open_rate, precision: 1) %></p>
<% end %>
```

### Decorate it

With [Draper](../../guide/gems/draper/), decorate the value with `decorates_assigned`, as you would a record. Pass the decorator with `with:`, because the value isn't a model. `decorates_assigned` adds the helper method for you, and the decorator formats the value the same way on every page.

```ruby
class PostsController < ApplicationController
  decorates_assigned :newsletter_stats,
    with: NewsletterStatsDecorator

  # GET /posts/:id
  def show
    @newsletter_stats = fetch_newsletter_stats
  end

  # ...
end
```

```ruby
class NewsletterStatsDecorator < ApplicationDecorator
  def open_rate
    h.number_to_percentage(object.open_rate, precision: 1)
  end
end
```

```erb
<% if newsletter_stats %>
  <p>Open rate: <%= newsletter_stats.open_rate %></p>
<% end %>
```

## A value for each record

A list must not make one request for each record. Each request adds to the time the page takes, and a long list can run into the other service's rate limits.

### Fetch them in one call

Read the values for every record in one call, e.g. `NewsletterClient#fetch_all_stats`, which returns the stats keyed by newsletter ID. Give the view a helper method that looks up one record's value. The lookup never makes a request.

This needs the other service to read many values at once. If it can't, look at [loading each value in its own frame](#load-each-value-in-its-own-frame).

```ruby
class PostsController < ApplicationController
  helper_method :newsletter_stats_for

  # GET /posts
  def index
    @posts = Post.all
    @newsletter_stats = fetch_newsletter_stats(@posts)
  end

  private

  def fetch_newsletter_stats(posts)
    NewsletterClient.new.fetch_all_stats(posts.filter_map(&:newsletter_id))
  end

  def newsletter_stats_for(post)
    @newsletter_stats[post.newsletter_id]
  end
end
```

```erb
<% @posts.each do |post| %>
  <% if (stats = newsletter_stats_for(post)) %>
    <p>Open rate: <%= number_to_percentage(stats.open_rate, precision: 1) %></p>
  <% end %>
<% end %>
```

### Pass the values to the decorators

With Draper, fetch the values in one call as above, then pass them to each record's decorator in its [context](../../guide/gems/draper/#context). The decorator looks up its own value and decorates it, so the view calls `post.newsletter_stats`. The decorator gets the values, never the service.

```ruby
class PostsController < ApplicationController
  helper_method :newsletter_stats

  decorates_assigned :posts,
    context: ->(c) { { newsletter_stats: c.helpers.newsletter_stats } }

  # GET /posts
  def index
    @posts = Post.all
    @newsletter_stats = fetch_newsletter_stats(@posts)
  end

  private

  attr_reader :newsletter_stats

  # ...
end
```

```ruby
class PostDecorator < ApplicationDecorator
  def newsletter_stats
    stats = context.fetch(:newsletter_stats)[object.newsletter_id]
    NewsletterStatsDecorator.new(stats) if stats
  end
end
```

```erb
<% posts.each do |post| %>
  <% if post.newsletter_stats %>
    <p>Open rate: <%= post.newsletter_stats.open_rate %></p>
  <% end %>
<% end %>
```

The decorator spec builds the values in the example and passes them in the context, as it would a record.

### Load each value in its own frame

When the other service is slow, or can't read many values at once, load each value in its own Turbo Frame. The list renders straight away, and each frame asks its own controller for one value. That controller reads one value for its page, as in [Assign it in the action](#assign-it-in-the-action).

```erb
<% @posts.each do |post| %>
  <%= turbo_frame_tag dom_id(post, :newsletter_stats),
    src: post_newsletter_stats_path(post),
    loading: :lazy %>
<% end %>
```

```ruby
module Posts
  class NewsletterStatsController < BaseController
    # GET /posts/:post_id/newsletter_stats
    def show
      # ...

      @newsletter_stats = NewsletterClient.new.fetch_stats(@post.newsletter_id)
    end
  end
end
```

The browser still makes one request for each record, but the server makes them one at a time as frames come into view, and the page doesn't wait for them.

### Store the value on the record

When the value can be a little out of date, copy it onto the record with a job, e.g. a `newsletter_open_rate` column on `posts`. The list then makes no requests at all. You can also sort and filter by the value, which no other pattern allows.

```ruby
class SyncNewsletterStatsJob < ApplicationJob
  def perform(post)
    stats = NewsletterClient.new.fetch_stats(post.newsletter_id)
    post.update!(newsletter_open_rate: stats.open_rate)
  end
end
```

This is the most work. You need to decide when the job runs, and the page shows the value from the last time it did.

## What to avoid

Don't call the service from a helper method, e.g. `@newsletter_stats ||= NewsletterClient.new.fetch_stats(@post.newsletter_id)`. The view then decides when the request is made, and an error from the service stops the page halfway through rendering.

Don't call the service from a decorator, or pass the service in its context. A list calls the decorator once for each record, so it makes one request for each one, and the decorator spec has to stub the request.
