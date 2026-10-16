---
applyTo: "app/models/**/*.rb,app/views/**/*,app/inputs/**/*.rb,app/helpers/**/*.rb,config/initializers/simple_form.rb"
---

# Simple Form

- Build forms with `simple_form_for`, passing a model or a form object, e.g. `simple_form_for @create_post_form`. You MUST NOT use `form_with` in an app that uses Simple Form.
- Add each field with `form.input`, not a Rails field helper, e.g. `form.input :title` instead of `form.text_field :title`.
- Pass a field's choices from the form object's `collection_for_<attribute>` method, read through `form.object`, e.g. `form.input :category, collection: form.object.collection_for_category`. You MUST NOT read the form's instance variable for it, e.g. `@create_post_form.collection_for_category`.
- Style inputs only in the wrappers in `config/initializers/simple_form.rb`. You MUST NOT style a single input in a view with `input_html`, `label_html` or `wrapper_html`, e.g. `input_html: { class: "form-control-lg" }`.
- When some forms need a different layout, add a named wrapper to `config/initializers/simple_form.rb` and pick it with `wrapper:`, e.g. `config.wrappers :inline` and `simple_form_for @search_form, wrapper: :inline`.
- Give each model that a form can pick a `to_label` method, returning the text to show in a select, in a `concerning :Labels` block under a `### Modules (SimpleForm) ###` heading, e.g. `def to_label = body.truncate(50)` in `Comment`. You MUST NOT build `[label, id]` pairs for a select, e.g. `comments.map { |comment| [comment.body, comment.id] }`.
- When a model changes `to_param`, e.g. to a slug with FriendlyId, keep the form object's attribute named after the model's column, but make it a `:string` and validate it against the same param, e.g. `attribute :featured_comment_id, :string` with `pluck(:slug)` instead of `pluck(:id)`. In `submit`, find the record by its slug, e.g. `collection_for_featured_comment_id.find_by!(slug: featured_comment_id)`. You MUST NOT pass the attribute to `where(id:)` or `find`.
- For an attribute that picks a record, write a custom select input for the resource in `app/inputs/`, and use it with `as:`, passing the choices with `collection:` from the form object, e.g. `CommentSelectInput` in `app/inputs/comment_select_input.rb` and `form.input :featured_comment_id, as: :comment_select, collection: form.object.collection_for_featured_comment_id`.
- In a custom select input, take the choices from the `collection:` option and pass them to a helper in the resource's helper file that returns the records in the order to show them and does any grouping, e.g. `template.comment_select_options(options.delete(:collection))` with `comment_select_options` in `app/helpers/comments_helper.rb`. You MUST NOT call `collection_for_<attribute>` from the input.
- In a custom select input, set the label and value methods in `input`, e.g. `options.reverse_merge!(label_method: :to_label, value_method: :to_param)` before `super`. You MUST NOT let Simple Form guess them.
- For a flat list, inherit the input from `SimpleForm::Inputs::CollectionSelectInput`, override the private `collection` method, and return the records from the helper, e.g. `comments.sort_by(&:to_label)`.
- For a grouped list, inherit the input from `SimpleForm::Inputs::GroupedCollectionSelectInput`, override the private `grouped_collection` method, and return `[group_label, records]` pairs from the helper, e.g. `comments.group_by(&:author).map { |author, author_comments| [author.name, author_comments.sort_by(&:to_label)] }`.
