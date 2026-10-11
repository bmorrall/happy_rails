---
title: Actions
parent: Testing
nav_order: 6
---

# Actions

How I test actions.

For the code itself, see [Actions](../../guide/actions/).

Write an action spec as a unit spec, and name the `describe` block `".call"`, after the method the spec calls. Stub everything the action calls, and check that it calls each one with the right arguments. Avoid creating records, even when the action runs a query. The request and job specs for its callers run the action for real, so its unit spec only checks what the action asks for.

Use `instance_double`, e.g. `instance_double(Post)`, not a plain `double`. See [RSpec: Doubles, build_stubbed or create](../gems/rspec/#doubles-build_stubbed-or-create).

An action does one task, so its unit spec stays short. If the spec needs a lot of stubs to set up, the action is often doing too much. Split it into smaller actions. If a chain of calls is hard to stub, move the chain into a method on the model, so the spec stubs one method. See [Models: Scopes and queries](../../guide/models/#scopes-and-queries).

```ruby
RSpec.describe Posts::ArchivePost do
  describe ".call" do
    it "archives the post and locks its comments" do
      travel_to Time.zone.now

      post = instance_double(Post, published?: false)
      comments = instance_double(ActiveRecord::Relation)
      allow(post).to receive(:comments).and_return(comments)

      expect(post).to receive(:update!).with(archived_at: Time.zone.now)
      expect(comments).to receive(:update_all).with(locked: true, updated_at: Time.zone.now)

      described_class.call(post)
    end
  end
end
```

Stub a collaborator to raise an error, to check that the action raises its own `Error` in its place.

```ruby
it "raises an Error when the post is invalid" do
  post = instance_double(Post, published?: false)
  allow(post).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)

  expect { described_class.call(post) }.to raise_error(described_class::Error)
end
```

When the action calls another action, stub that action, and check that the action calls it with the right arguments, e.g. `expect(Posts::UnpublishPost).to receive(:call).with(post)`. The other action has its own spec, so this spec only checks that the action asks for it. To check that the action raises its own `Error` in place of the other action's, stub the other action to raise its `Error`.

```ruby
it "unpublishes a published post before archiving it" do
  travel_to Time.zone.now

  comments = instance_double(ActiveRecord::Relation)
  post = instance_double(Post, published?: true, comments:)
  allow(comments).to receive(:update_all)

  expect(Posts::UnpublishPost).to receive(:call).with(post)
  expect(post).to receive(:update!).with(archived_at: Time.zone.now)

  described_class.call(post)
end

it "raises an Error when the post can't be unpublished" do
  post = instance_double(Post, published?: true)
  allow(Posts::UnpublishPost).to receive(:call).and_raise(Posts::UnpublishPost::Error)

  expect { described_class.call(post) }.to raise_error(described_class::Error)
end
```

When the action writes to a relation, stub the method that returns it, e.g. `post.unlocked_comments` or `Comment.on_posts(posts)`, to return an `instance_double(ActiveRecord::Relation)`. Then expect the write on it. Pass a relation double in as the records, e.g. `posts` for `Posts::ArchivePosts`.

```ruby
RSpec.describe Posts::ArchivePosts do
  describe ".call" do
    it "archives the posts and locks their comments" do
      travel_to Time.zone.now

      posts = instance_double(ActiveRecord::Relation)
      comments = instance_double(ActiveRecord::Relation)
      allow(Comment).to receive(:on_posts).with(posts).and_return(comments)

      expect(comments).to receive(:update_all).with(locked: true, updated_at: Time.zone.now)
      expect(posts).to receive(:update_all).with(archived_at: Time.zone.now, updated_at: Time.zone.now)

      described_class.call(posts)
    end
  end
end
```

When the action loops with `find_each`, stub it to yield doubles, e.g. `allow(posts).to receive(:find_each).and_yield(post)`.

When the action takes a lock, stub `with_lock` to yield, e.g. `allow(post).to receive(:with_lock).and_yield`. The block then runs against the same double. To test the check inside the lock, return one answer for the check before the lock and another for the check inside it, e.g. `allow(post).to receive(:published?).and_return(false, true)`.

```ruby
RSpec.describe Posts::PublishPost do
  describe ".call" do
    it "publishes a draft" do
      publisher = instance_double(User)
      publications = instance_double(ActiveRecord::Relation)
      post = instance_double(Post, published?: false, has_changes_to_save?: false, publications:)
      allow(post).to receive(:with_lock).and_yield

      expect(post).to receive(:update!).with(status: :published)
      expect(publications).to receive(:create!).with(publisher:)

      described_class.call(post, publisher:)
    end

    it "does nothing when the post is published while it waits for the lock" do
      post = instance_double(Post, has_changes_to_save?: false)
      allow(post).to receive(:published?).and_return(false, true)
      allow(post).to receive(:with_lock).and_yield

      expect(post).not_to receive(:update!)

      described_class.call(post, publisher: instance_double(User))
    end
  end
end
```

When the action calls a chain of methods, e.g. `PublishScheduledPostJob.set(wait_until: post.publish_at).perform_later(post)` in `Posts::EnqueuePublish`, stub the chain with `allow(...).to receive_message_chain`. After the call, check each step's arguments with `have_received`. Use `allow`, not `expect`. `have_received` only works on a stub, and `with` on the chain only checks the last step.

```ruby
RSpec.describe Posts::EnqueuePublish do
  describe ".call" do
    it "enqueues the post to publish at its publish time" do
      publish_at = Time.zone.local(2026, 10, 31, 9, 0)
      post = instance_double(Post, publish_at:)
      allow(PublishScheduledPostJob).to receive_message_chain(:set, :perform_later)

      described_class.call(post)

      expect(PublishScheduledPostJob).to have_received(:set).with(wait_until: publish_at)
      expect(PublishScheduledPostJob.set).to have_received(:perform_later).with(post)
    end
  end
end
```

When the action calls another service, stub the service like any other collaborator, with an `instance_double` returned from the method the action builds it with, e.g. `NewsletterClient.new`. You MUST NOT stub the HTTP request in an action spec. The service's own spec checks the requests it sends, so the action spec only checks what the action asks the service for.

When the action builds the service with its default constructor, e.g. `NewsletterClient.new`, set up the stubbed client in a `let`. Every example gets the same client, so the `let` hides nothing about the example. Each example then stubs the methods it needs on `newsletter_client`, which also sets up the `let`.

To check the action's errors, stub the service to raise each error the action handles. Raise an error built with the details a real failure carries, e.g. `NewsletterClient::Error.new("Server error", status: 500)`, not the bare class, so a check on the error's details has something to compare.

```ruby
RSpec.describe Posts::SendNewsletter do
  let(:newsletter_client) do
    instance_double(NewsletterClient).tap do |newsletter_client|
      allow(NewsletterClient).to receive(:new).and_return(newsletter_client)
    end
  end

  describe ".call" do
    it "raises a ServiceError when the newsletter service fails" do
      post = instance_double(Post)
      allow(newsletter_client).to receive(:create_newsletter).with(post)
        .and_raise(NewsletterClient::Error.new("Server error", status: 500))

      expect { described_class.call(post) }.to raise_error(described_class::ServiceError)
    end
  end
end
```

When the action builds the service for a record, e.g. `NewsletterClient.for(integration)`, write a helper method that takes the record and returns the stubbed client, instead of a `let`. Name it `stub_`, then the service, then `_for`, e.g. `stub_newsletter_client_for(integration)`. The client depends on the record, so each example builds the record and passes it in, and shows which record the client is for. Define the helper at the bottom of the spec file, inside the top-level `describe` block, after the examples.

```ruby
RSpec.describe Posts::SendNewsletter do
  describe ".call" do
    it "raises a ServiceError when the newsletter service fails" do
      integration = instance_double(NewsletterServiceIntegration)
      post = instance_double(Post)
      newsletter_client = stub_newsletter_client_for(integration)
      allow(newsletter_client).to receive(:create_newsletter).with(post)
        .and_raise(NewsletterClient::Error.new("Server error", status: 500))

      expect { described_class.call(post, integration:) }.to raise_error(described_class::ServiceError)
    end
  end

  def stub_newsletter_client_for(integration)
    instance_double(NewsletterClient).tap do |newsletter_client|
      allow(NewsletterClient).to receive(:for).with(integration).and_return(newsletter_client)
    end
  end
end
```

The unit spec checks the action alone. The request and job specs for its callers let it run for real, so between them they check that it works with the rest of the app.

## Checking arguments

`ValidatedCallable` runs the action's argument validations inside `call`, so they run in the action's own spec too. A validator that calls a method on a record calls it on the record double, and an `instance_double` raises for a method you didn't stub. In the action's spec, stub each method that the argument validations call on a record double, e.g. `instance_double(Post, has_changes_to_save?: false)` for `unmodified:`. `UnmodifiedValidator` calls `has_changes_to_save?` on the record.

You MUST NOT test the argument checks in request or job specs, e.g. that `Posts::PublishPost` raises `ActiveModel::ValidationError` for a post with unsaved changes. Every spec that calls the action already runs them, and fails if the controller or job passes the wrong arguments. Test each validator once, in its own spec.

## Specs for callers

You MUST NOT stub or mock an action in a request spec or a job spec, e.g. with `allow(Posts::ArchivePost).to receive(:call)` or `expect(Posts::ArchivePost).to receive(:call).with(post)`. To these specs, the action is invisible. The same goes for the form that calls it. Let them run, and check what the controller or job does: the records it changes, the response, the flash and the jobs it enqueues.

An action is a detail of how the controller or job does its work. If the spec checks the result, you can move code into an action, or out of it, without changing the spec. A spec that stubs the action only checks that the action was called. It still passes when the action is broken, or when the action is called with the wrong arguments.

```ruby
module Posts
  class ArchivesController < BaseController
    # POST /posts/:post_id/archive
    def create
      # ...

      @archive_post_form = ArchivePostForm.new(@post, current_user)

      if @archive_post_form.submit
        redirect_to posts_path,
          notice: "Post was archived."
      else
        redirect_to post_path(@post),
          alert: "Post could not be archived."
      end
    end
  end
end
```

```ruby
RSpec.describe "Posts::Archives" do
  describe "POST /posts/:post_id/archive", :aggregate_failures do
    # ...

    it "archives the post" do
      published_post = create(:post)
      comment = create(:comment, post: published_post)

      expect {
        post post_archive_path(published_post)
      }.to change { published_post.reload.archived_at }.from(nil)

      expect(comment.reload).to be_locked
      expect(response).to redirect_to(posts_path)
      expect(flash.to_hash).to match("notice" => "Post was archived.")
    end
  end
end
```

To test how a caller handles the action's `Error`, set up records that make the action fail for real. You MUST NOT stub the action to raise it, e.g. with `allow(Posts::ArchivePost).to receive(:call).and_raise(Posts::ArchivePost::Error)`.
