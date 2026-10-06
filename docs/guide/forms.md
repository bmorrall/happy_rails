---
title: Forms
parent: The Guide
nav_order: 5
---

# Forms

How form objects are written and organised.

If your app uses a gem for form objects, e.g. [Reform](https://github.com/trailblazer/reform), follow the gem's conventions. The rest of this page is for apps that write their own form objects. Treat it as a set of suggestions.

Put form objects in `app/forms/`, e.g. `CreatePostForm` in `app/forms/create_post_form.rb`.

## Naming

Name a form after the action and the resource it handles, e.g. `CreatePostForm` and `UpdatePostForm`, or `PublishPostForm` for publishing a post. The name says what the form does, so each action can have its own attributes and validations.

```ruby
class CreatePostForm
  # ...
end
```

## Base class

Give every form a base class, `ApplicationForm`, in `app/forms/application_form.rb`. It takes the current user and the params, so every form knows who is submitting it. A resource form or action form takes its resource as the first argument, before the current user, and keeps it in its own private `attr_reader`. It also includes `ActiveModel::Validations::Callbacks`, so forms can use `before_validation` and `after_validation`, and `ActiveModel::Attributes::Normalization`, so forms can use `normalizes`. `ActiveModel::Model` includes neither. `ActiveModel::Attributes::Normalization` needs Rails 8.1 or later.

```ruby
class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Attributes::Normalization
  include ActiveModel::Validations::Callbacks

  def initialize(current_user, params = {})
    @current_user = current_user
    super(params)
  end

  private

  attr_reader :current_user
end
```

## Layout

Group the declarations in a form object under comment headings, in the same style as [models](../models/), in this order:

1. Attributes
2. Collections
3. Validations
4. Callbacks
5. Public Methods, e.g. `submit`

Put the setup at the top, without a heading: `self.model_name`, any `delegate` lines, then `initialize`. A reader then sees first what the form needs to be built. Put `submit` under Public Methods, after the declarations it uses, as in a model. Private methods go last, after `private`.

```ruby
class CreatePostForm < ApplicationForm
  def self.model_name
    Post.model_name
  end

  delegate :to_param, :to_partial_path, :persisted?, :new_record?,
    to: :post

  def initialize(post, current_user, params = {})
    @post = post
    super(current_user, params)
  end

  ### Attributes ###

  # ...

  ### Public Methods ###

  def submit
    # ...
  end

  private

  attr_reader :post
end
```

Under Collections, write a `collection_for_<attribute>` method for each attribute that has a fixed set of choices. The form's select uses it for its options, and the validations use it to check the value.

```ruby
class CreatePostForm < ApplicationForm
  # ...

  ### Attributes ###

  attribute :title, :string

  attribute :status, :string

  ### Collections ###

  def collection_for_status
    Post.statuses.keys
  end

  ### Validations ###

  validates :status,
    inclusion: { in: ->(form) { form.collection_for_status } }
end
```

Write a form's validations as you would a model's, e.g. add `allow_blank: true` next to `presence: true`. See [Models: Validations](../models/#validations).

Tidy a form attribute with `normalizes` under `### Attributes ###`, as in a model, e.g. `normalizes :title, with: ->(title) { title.strip }`. Don't use a `before_validation` callback for it. See [Models: Normalising values](../models/#normalising-values). Form objects can use `normalizes` from Rails 8.1. Before that, leave `ActiveModel::Attributes::Normalization` out of `ApplicationForm`, and tidy the value in a `before_validation` callback under `### Callbacks ###`, e.g. `before_validation { self.title = title&.strip }`.

```ruby
class CreatePostForm < ApplicationForm
  ### Attributes ###

  attribute :title, :string

  normalizes :title,
    with: ->(title) { title.strip }

  # ...
end
```

### Association ids

For an association id, e.g. `featured_comment_id`, return a scope of the records the user may pick. Validate the id with an inclusion validator that uses the same method. In the validator, limit the collection to the submitted id with `where`, then `pluck` the ids. The validation then loads one id, not every record in the collection.

```ruby
class UpdatePostForm < ApplicationForm
  # ...

  ### Attributes ###

  attribute :featured_comment_id, :integer

  ### Collections ###

  def collection_for_featured_comment_id
    post.comments
  end

  ### Validations ###

  validates :featured_comment_id,
    inclusion: { in: ->(form) { form.collection_for_featured_comment_id.where(id: form.featured_comment_id).pluck(:id) } },
    allow_nil: true
end
```

## Resource forms

A resource form wraps a single model instance, e.g. a `CreatePostForm` that wraps a new `Post`. Use one when a form needs its own attributes or validations, but still creates or updates one record.

So the form works with `form_with`, delegate `to_param`, `to_partial_path`, `persisted?` and `new_record?` to the resource. Then add a `model_name` class method that returns the resource's `model_name`. `form_with` then picks the same URL, method and param key as it would for the model, e.g. `POST /posts` with params under `post`.

```ruby
class CreatePostForm < ApplicationForm
  def self.model_name
    Post.model_name
  end

  delegate :to_param, :to_partial_path, :persisted?, :new_record?,
    to: :post

  def initialize(post, current_user, params = {})
    @post = post
    super(current_user, params)
  end

  # ...

  private

  attr_reader :post
end
```

```erb
<%= form_with model: @create_post_form do |form| %>
  <%# ... %>
<% end %>
```

Keep the resource in a private `attr_reader`. Callers use the form, not the record inside it.

Set the form's attributes from the resource's existing values in `initialize`, with `reverse_merge`. The params the user submitted win, and the resource fills in the rest. The edit page then shows the record's current values, and a field the user didn't send keeps its value.

```ruby
class UpdatePostForm < ApplicationForm
  # ...

  def initialize(post, current_user, params = {})
    @post = post
    super(current_user, params.reverse_merge(title: post.title, status: post.status))
  end
end
```

The form looks up its translations under `activemodel`, not `activerecord`, because it is not an Active Record model. Alias the model's translations in your locale file, so the form and the model share them.

```yaml
en:
  activerecord:
    attributes:
      post: &post_attributes
        title: Title
  activemodel:
    attributes:
      post: *post_attributes
```

### Action forms

A form for an action, e.g. publishing a post, still wraps the resource, but it doesn't create or update it. Give it a custom `model_name`, so its params get their own key, e.g. `publication` for `Posts::PublicationsController`. Override `persisted?` to return `false` and `new_record?` to return `true`, so `form_with` sends a `POST`, not a `PATCH`.

```ruby
class PublishPostForm < ApplicationForm
  def self.model_name
    ActiveModel::Name.new(self, nil, "Publication")
  end

  def initialize(post, current_user, params = {})
    @post = post
    super(current_user, params)
  end

  def persisted?
    false
  end

  def new_record?
    true
  end

  # ...

  private

  attr_reader :post
end
```

Pass the `url` to `form_with`. The action's route is a singular `resource`, which `form_with` can't work out from the model name.

```erb
<%= form_with model: @publish_post_form, url: post_publication_path(@post) do |form| %>
  <%# ... %>
<% end %>
```

### Nested forms

A form that creates a nested resource, e.g. a comment on a post, goes in a module named after the parent, like its controller, e.g. `Posts::CreateCommentForm` in `app/forms/posts/create_comment_form.rb` for `Posts::CommentsController`. See [Controllers and Routes: Nested resources](../controllers/#nested-resources).

Take the parent as the first argument, before the current user, and build the new resource for it in `initialize`, e.g. `Comment.new(post: post)`. The controller only passes the post it already loaded, and the comment always belongs to that post. Set any default values from the parent with `reverse_merge`, so the params the user submitted still win. Keep both records in private `attr_reader`s, and delegate to the new resource as for any resource form.

```ruby
module Posts
  class CreateCommentForm < ApplicationForm
    def self.model_name
      Comment.model_name
    end

    delegate :to_param, :to_partial_path, :persisted?, :new_record?,
      to: :comment

    def initialize(post, current_user, params = {})
      @post = post
      @comment = Comment.new(post: post)
      super(current_user, params.reverse_merge(subject: "Re: #{post.title}"))
    end

    # ...

    private

    attr_reader :post, :comment
  end
end
```

```ruby
def create
  @create_comment_form = Posts::CreateCommentForm.new(@post, current_user, comment_params)
  # ...
end
```

Don't build it with `post.comments.new`. That adds the unsaved comment to `post.comments` in memory, so a page that shows the form and lists `@post.comments` would end the list with an empty comment. `Comment.new(post: post)` sets the same post, without changing the post's comments.

A nested form that updates a resource, e.g. `Posts::UpdateCommentForm`, takes the existing comment as its first argument instead, like any resource form. The comment already belongs to its post.

Pass the parent and the form to `form_with` as an array. It then builds the nested URL, e.g. `POST /posts/:post_id/comments`.

```erb
<%= form_with model: [@post, @create_comment_form] do |form| %>
  <%# ... %>
<% end %>
```

## Submitting

Process every form with the same method, typically `submit`. It returns the result, or `false` if the form is invalid. Every form then works the same way in a controller, whatever it does. If the app already uses another name, e.g. `save`, use that instead.

A resource form's `submit` returns the saved resource, or `false` if the save fails. The controller can then redirect to the record it gets back.

```ruby
class CreatePostForm
  # ...

  ### Public Methods ###

  def submit
    return false unless valid?

    post.assign_attributes(attributes)
    post.save ? post : false
  end
end
```

```ruby
def create
  @create_post_form = CreatePostForm.new(Post.new, current_user, post_params)

  if (post = @create_post_form.submit)
    redirect_to post,
      notice: "Post was created."
  else
    render :new,
      status: :unprocessable_entity
  end
end
```

When the resource fails to save, copy its errors onto the form, so the form shows them. Add an error on a form attribute to that attribute, and add the full message of any other error to `:base`. Keep each error's type, e.g. `:blank`, so code that checks `errors.details` or `of_kind?` still works.

```ruby
class CreatePostForm
  # ...

  ### Public Methods ###

  def submit
    return false unless valid?

    post.assign_attributes(attributes)
    return post if post.save

    merge_errors_from(post)
    false
  end

  private

  def merge_errors_from(record)
    record.errors.each do |error|
      if self.class.attribute_names.include?(error.attribute.to_s)
        errors.add(error.attribute, error.type, message: error.message)
      else
        errors.add(:base, error.type, message: error.full_message)
      end
    end
  end
end
```

If the resource's errors could show the user something they shouldn't see, add a generic error to `:base` instead.

```ruby
errors.add(:base, "Post could not be saved.")
```

### Saving several records

When `submit` saves more than one record, wrap the saves in a transaction, and use the `!` methods, e.g. `update!` and `create!`. Either every record saves, or none do. Rescue `ActiveRecord::RecordInvalid`, copy the failed record's errors onto the form, and return `false`, as for a single save.

Enqueue jobs and send emails after the transaction, not inside it. A job enqueued inside it could run before the records are committed, and not find them. It could also run for records that were rolled back.

```ruby
class PublishPostForm < ApplicationForm
  # ...

  ### Public Methods ###

  def submit
    return false unless valid?

    ActiveRecord::Base.transaction do
      post.update!(status: :published)
      post.publications.create!(publisher: current_user)
    end

    NotifySubscribersJob.perform_later(post)
    post
  rescue ActiveRecord::RecordInvalid => e
    merge_errors_from(e.record)
    false
  end
end
```

### Calling actions

A form handles what the user submits: it checks the input, then does the work. When the work could be run from somewhere else too, e.g. a job or the console, put it in an [action](../actions/) and call the action from `submit`. The form deals with the user and their input, and the action does the task. See [Actions: When to write an action](../actions/#when-to-write-an-action).

Call the action after `valid?`, and pass it the records and values it needs. Never pass it the form or the params. The action then doesn't depend on how the user submitted the data. Never pass it a record with unsaved changes, e.g. after `post.title = title`. Pass the new values as keywords instead, e.g. `title:`. See [Actions: Arguments](../actions/#arguments). Pass the current user as an argument named after the role the user plays, e.g. `publisher: current_user`. See [Principles: The signed-in user](../principles/#the-signed-in-user).

The action returns nothing, so `submit` returns the resource itself, as for any resource form. Rescue the action's `Error` in `submit`, add an error to `:base`, and return `false`, so the form shows the failure.

```ruby
class PublishPostForm < ApplicationForm
  # ...

  ### Public Methods ###

  def submit
    return false unless valid?

    Posts::PublishPost.call(post, publisher: current_user)
    NotifySubscribersJob.perform_later(post)
    post
  rescue Posts::PublishPost::Error
    errors.add(:base, "Post could not be published.")
    false
  end
end
```

An action that writes more than once has its own transaction. Open a transaction in `submit` only to combine several actions, or an action and the form's own save, into one unit. Call any `Record` action before or after that transaction, never inside it. To record that the transaction failed, call the `Record` action in a `rescue` or `ensure` on `submit`. See [Actions: Transactions](../actions/#transactions).

```ruby
def submit
  return false unless valid?

  ActiveRecord::Base.transaction do
    Posts::PublishPost.call(post, publisher: current_user)
    Posts::ArchivePost.call(previous_post)
  end

  NotifySubscribersJob.perform_later(post)
  post
rescue Posts::PublishPost::Error, Posts::ArchivePost::Error
  errors.add(:base, "Post could not be published.")
  false
end
```

## Testing

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

Test a form attribute that uses a custom validator with the validator's matcher, as in a model spec, e.g. `it { is_expected.to validate_isbn_of(:isbn) }`. See [Validators: Models and forms that use a validator](../validators/#models-and-forms-that-use-a-validator).
