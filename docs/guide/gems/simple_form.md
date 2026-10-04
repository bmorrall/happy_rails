---
title: Simple Form
parent: Gems
grand_parent: The Guide
nav_order: 6
---

# Simple Form

Form inputs with [Simple Form](https://github.com/heartcombo/simple_form).

## Building forms

Build forms with `simple_form_for`, and pass it a model or a form object, as you would with `form_with`. See [Views and Frontend: Forms](../../views/#forms).

Add each field with `form.input`, not a Rails field helper, e.g. `form.text_field`. `form.input` wraps the field with its label, hint and errors, so every field on every form is built the same way.

Pass a field's choices from the form object's `collection_for_<attribute>` method, and read the form object through `form.object`, e.g. `collection: form.object.collection_for_status`. Don't use the instance variable, e.g. `@create_post_form`. The fields then only depend on the form they're in, so you can move them to a partial or share them between forms without changing them.

```erb
<%# app/views/posts/new.html.erb %>
<%= simple_form_for @create_post_form do |form| %>
  <%= form.input :title %>
  <%= form.input :status, collection: form.object.collection_for_status %>
  <%= form.button :submit %>
<% end %>
```

## Styling inputs

Style inputs in one place: the wrappers in `config/initializers/simple_form.rb`. Don't style a single input in a view with `input_html`, `label_html` or `wrapper_html`, e.g. `input_html: { class: "form-control-lg" }`. Every form then looks the same, and you can change how inputs look across the app in one file.

When some forms need a different layout, e.g. a search form with its fields in one row, add a named wrapper to the initializer and pick it with `wrapper:`.

```ruby
# config/initializers/simple_form.rb
SimpleForm.setup do |config|
  # ...

  config.wrappers :inline do |b|
    # ...
  end
end
```

```erb
<%= simple_form_for @search_form, wrapper: :inline do |form| %>
  <%# ... %>
<% end %>
```

Don't style the input in the view.

```erb
<%= form.input :title, input_html: { class: "form-control-lg" }, wrapper_html: { class: "mb-4" } %>
```

## Select inputs

Give each model that a form can pick a `to_label` method, which returns the text to show for the record in a select. Simple Form calls it, not your app, so put it in a `concerning :Labels` block under a `### Modules (SimpleForm) ###` heading, as for any other gem. See [Models: Layout](../../models/#layout). The heading then says why the method is there, so no one removes it as unused.

```ruby
# app/models/comment.rb
class Comment < ApplicationRecord
  # ...

  ### Modules (SimpleForm) ###

  concerning :Labels do
    def to_label
      body.truncate(50)
    end
  end
end
```

The select input uses `to_label` for each option's label and `to_param` for its value, so you don't build `[label, id]` pairs by hand. `to_param` is how Rails turns a record into a param when it builds a URL, so the select sends the same value as the record's URL, and one lookup works for both. For most models it's the id.

When a model changes `to_param`, e.g. to a slug with FriendlyId, the select sends the slug, not the id. Make the form object's attribute a `:string`, and validate it against the same param, e.g. `pluck(:slug)` instead of `pluck(:id)`. See [Forms: Association ids](../../forms/#association-ids).

For an attribute that picks a record, e.g. `featured_comment_id`, write a custom select input for the resource, e.g. `CommentSelectInput` in `app/inputs/comment_select_input.rb`. Pass it the choices from the form object's `collection_for_<attribute>` method, as for any other field. See [Forms: Association ids](../../forms/#association-ids). The input passes them to a helper in the resource's helper file, e.g. `comment_select_options` in `CommentsHelper`. The helper returns the records in the order to show them, and groups them if the input is grouped.

Every select for a resource then shows its records the same way, wherever it is used. The input doesn't know where the records come from, so it works with any list of comments, from a form object or a plain model. You can also switch an input between a flat list and groups without changing a view. The helper has its own helper spec, so you can test the order and groups without a form.

Inherit from `SimpleForm::Inputs::CollectionSelectInput` for a flat list, and override `collection`. Set `label_method: :to_label` and `value_method: :to_param` in `input`, so Simple Form doesn't guess them. If the model has no `to_label`, Simple Form would quietly fall back to another method, e.g. `to_s`. With both set, the input raises an error instead.

```ruby
# app/inputs/comment_select_input.rb
class CommentSelectInput < SimpleForm::Inputs::CollectionSelectInput
  def input(wrapper_options = nil)
    options.reverse_merge!(label_method: :to_label, value_method: :to_param)
    super
  end

  private

  def collection
    @collection ||= template.comment_select_options(options.delete(:collection))
  end
end
```

```ruby
# app/helpers/comments_helper.rb
module CommentsHelper
  def comment_select_options(comments)
    comments.sort_by(&:to_label)
  end
end
```

```erb
<%# app/views/posts/edit.html.erb %>
<%= simple_form_for @update_post_form do |form| %>
  <%= form.input :featured_comment_id, as: :comment_select, collection: form.object.collection_for_featured_comment_id %>
  <%# ... %>
<% end %>
```

When the options are easier to find in groups, e.g. comments grouped by their author, inherit from `SimpleForm::Inputs::GroupedCollectionSelectInput` instead, and override `grouped_collection`. Set the label and value methods in the same way. The helper then returns each group's label with its records.

```ruby
# app/inputs/comment_select_input.rb
class CommentSelectInput < SimpleForm::Inputs::GroupedCollectionSelectInput
  def input(wrapper_options = nil)
    options.reverse_merge!(label_method: :to_label, value_method: :to_param)
    super
  end

  private

  def grouped_collection
    @grouped_collection ||= template.comment_select_options(options.delete(:collection))
  end
end
```

```ruby
# app/helpers/comments_helper.rb
module CommentsHelper
  def comment_select_options(comments)
    comments.group_by(&:author).map do |author, author_comments|
      [author.name, author_comments.sort_by(&:to_label)]
    end
  end
end
```

## Testing

> **TODO:** Describe how you handle this.
