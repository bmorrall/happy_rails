---
applyTo: "app/forms/**/*.rb,spec/forms/**/*.rb"
---

# Forms

- If the app uses a gem for form objects, e.g. Reform, follow the gem's conventions and ignore the rules below.
- Otherwise, follow the rules below for form objects the app writes itself.
- Put form objects in `app/forms/`, e.g. `CreatePostForm` in `app/forms/create_post_form.rb`.
- Name a form after its action and resource, e.g. `CreatePostForm`, `UpdatePostForm` or `PublishPostForm`.
- Inherit every form from `ApplicationForm` in `app/forms/application_form.rb`, which includes `ActiveModel::Model`, `ActiveModel::Attributes` and `ActiveModel::Validations::Callbacks`, takes the current user and the params in `initialize(current_user, params = {})`, and keeps `current_user` in a private `attr_reader`.
- Group form object declarations under comment headings in this order: `### Attributes ###`, `### Collections ###`, `### Validations ###`, `### Callbacks ###`, `### Public Methods ###`.
- Put a form's setup at the top, without a heading, in this order: `self.model_name`, any `delegate` lines, then `initialize`. Put `submit` under `### Public Methods ###`, and private methods last, after `private`, e.g. `attr_reader :post`.
- Under `### Collections ###`, write a `collection_for_<attribute>` method for each attribute with a fixed set of choices, and use it in the attribute's validation, e.g. `collection_for_status` returning `Post.statuses.keys`, and `validates :status, inclusion: { in: ->(form) { form.collection_for_status } }`.
- For an association id, return a scope from `collection_for_<attribute>` and validate the id with inclusion, limiting the scope to the submitted id with `where` and plucking the ids, e.g. `validates :featured_comment_id, inclusion: { in: ->(form) { form.collection_for_featured_comment_id.where(id: form.featured_comment_id).pluck(:id) } }, allow_nil: true` with `collection_for_featured_comment_id` returning `post.comments`.
- Write a resource form to wrap a single model instance when a form needs its own attributes or validations but still creates or updates one record, e.g. `CreatePostForm` wrapping a new `Post`.
- In a resource form, delegate `to_param`, `to_partial_path`, `persisted?` and `new_record?` to the resource, and add a `model_name` class method that returns the resource's `model_name`, e.g. `delegate :to_param, :to_partial_path, :persisted?, :new_record?, to: :post` and `def self.model_name = Post.model_name`.
- In a resource form or action form, take the resource as the first argument, before the current user and the params, and keep it in a private `attr_reader`, e.g. `def initialize(post, current_user, params = {})` setting `@post` then calling `super(current_user, params)`, and `attr_reader :post` after `private`.
- In a resource form, set the form's attributes from the resource's existing values in `initialize` with `reverse_merge`, so submitted params win, e.g. `super(current_user, params.reverse_merge(title: post.title, status: post.status))` in `UpdatePostForm`.
- Alias the model's `activerecord` translations under `activemodel` in the locale file, so a resource form uses the same translations as its model, e.g. `post: &post_attributes` under `activerecord.attributes` and `post: *post_attributes` under `activemodel.attributes`.
- In a resource form for an action, give it a custom `model_name` for its params key, and override `persisted?` to return `false` and `new_record?` to return `true`, e.g. `PublishPostForm` with `ActiveModel::Name.new(self, nil, "Publication")` for `POST /posts/:post_id/publication`. Pass the `url` to `form_with`, e.g. `form_with model: @publish_post_form, url: post_publication_path(@post)`.
- Put a form that creates a nested resource in a module named after the parent, like its controller, e.g. `Posts::CreateCommentForm` in `app/forms/posts/create_comment_form.rb` for `Posts::CommentsController`.
- In a nested form, take the parent as the first argument, build the new resource for it in `initialize`, and set defaults from the parent with `reverse_merge`, e.g. `def initialize(post, current_user, params = {})` setting `@post = post` and `@comment = Comment.new(post: post)`, then `super(current_user, params.reverse_merge(subject: "Re: #{post.title}"))`. Keep both in private `attr_reader`s, and delegate `to_param`, `to_partial_path`, `persisted?` and `new_record?` to the new resource, with `model_name` returning its `model_name`, e.g. `Comment.model_name`.
- In a nested form, never build the new resource through the parent's association, e.g. `post.comments.new`, because it adds the unsaved record to `post.comments`, and a page that lists them shows an empty record.
- In a nested form that updates a resource, take the existing resource as the first argument, like any resource form, e.g. `Posts::UpdateCommentForm.new(comment, current_user, comment_params)`.
- Pass the parent and a nested form to `form_with` as an array, e.g. `form_with model: [@post, @create_comment_form]`.
- Process every form with the same method, typically `submit`, that returns the result, or `false` if the form is invalid. If the app's existing forms use another name, e.g. `save`, use that name.
- In a resource form, return the saved resource from `submit`, or `false` if the form is invalid or the save fails, e.g. `if (post = @create_post_form.submit)` then `redirect_to post`.
- When a resource form fails to save its resource, copy the resource's errors onto the form: add an error on a form attribute to that attribute, and the full message of any other error to `:base`, and keep each error's type, e.g. `errors.add(error.attribute, error.type, message: error.message)` when `self.class.attribute_names` includes it, otherwise `errors.add(:base, error.type, message: error.full_message)`.
- If the resource's errors could show the user something they should not see, add a generic error to `:base` instead, e.g. `errors.add(:base, "Post could not be saved.")`.
- Cover every `collection_for_<attribute>` method with a unit test in `spec/forms/`, e.g. `describe "#collection_for_status"` in `spec/forms/create_post_form_spec.rb`.
