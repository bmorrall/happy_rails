---
applyTo: "app/actions/**/*.rb,spec/actions/**/*.rb"
---

# Actions

- Put service objects that do one task in `app/actions/`, e.g. `Posts::ArchivePost` in `app/actions/posts/archive_post.rb`.
- Keep actions separate from action forms. An action form handles what the user submits, e.g. `PublishPostForm`. An action is its own object that does a task, e.g. `Posts::ArchivePost`.
- Put each action in a module named after the resource it works on, in the plural, e.g. `Posts`. Name the action after the task, starting with a verb. The name can include the resource, e.g. `Posts::ArchivePost`, not `ArchivePost` or `Posts::ArchivePostAction`.
- Inherit every action from `ApplicationAction` in `app/actions/application_action.rb`. Define the class method `call` there to build the action, call it and return `nil`, e.g. `def self.call(...); new(...).call; nil; end`.
- Write an `initialize` that takes the action's arguments and an instance method `call` that does the task, e.g. `Posts::ArchivePost.new(post)` keeps `post` in a private `attr_reader`.
- Call an action with the class method, e.g. `Posts::ArchivePost.call(post)`, not `Posts::ArchivePost.new(post).call`.
- Never return a value from an action, and never use the value an action returns.
- When a caller needs a value from an action's work, have the action save it on a record the caller holds, and read it from the record after the call, e.g. `@post.newsletter_id` after `Posts::SendNewsletter.call(@post)`.
- When another service accepts an ID from you, generate the ID in the caller and pass it to the action, e.g. `newsletter_id = SecureRandom.uuid` then `Posts::SendNewsletter.call(@post, newsletter_id:)`.
- When an API client tracks a request to another service, create a record for the request first with your own ID, e.g. `has_secure_token :reference` on `NewsletterDelivery`. Send your ID to the service, and give the client your ID, never the service's.
- Never pass a value back from an action through a block or a result object, e.g. `Posts::SendNewsletter.call(post) { |newsletter_id| ... }` or `Result.new(success: true, value: response.id)`.
- For more ways to get a value from an action's work, see https://bmorrall.github.io/happy_rails/patterns/values-from-actions/.
- When an action's task fails, raise an error, e.g. with `update!`, rather than returning `false`.
- Let an error that no caller should handle pass through the action unchanged.
- When a caller is meant to handle an error, define a custom `Error` class inside the action that inherits from `StandardError`, e.g. `class Error < StandardError; end` in `Posts::ArchivePost`. In `call`, rescue the errors the caller should handle and raise them again as the action's `Error`, e.g. `rescue ActiveRecord::RecordInvalid => e` then `raise Error, e.message`.
- Rescue an action's `Error` in a form or a job, not in a controller, e.g. `rescue Posts::ArchivePost::Error` then `errors.add(:base, "Post could not be archived.")` and `false` in a form's `submit`.
- Write action specs as unit specs. Stub and mock the models and other objects the action uses, and check that the action calls them with the right arguments, e.g. `post = instance_double(Post)` then `expect(post).to receive(:update!).with(archived_at: an_instance_of(ActiveSupport::TimeWithZone))` before `described_class.call(post)`.
- In action specs, name the `describe` block after the method the spec calls, e.g. `describe ".call"`.
- In action specs, use `instance_double`, e.g. `instance_double(Post)`. Avoid a plain `double`, e.g. `double("post")`.
- If an action spec needs a lot of stubs to set up, split the action into smaller actions. If the action is simple but its objects take a lot of stubbing, e.g. a chain of associations, build real records with factories instead, e.g. `create(:post)`.
- In action specs, check the action's `Error` by stubbing a collaborator to raise the original error, e.g. `allow(post).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)` then `expect { described_class.call(post) }.to raise_error(described_class::Error)`.
- Never stub or mock an action in a request spec or a job spec, e.g. `allow(Posts::ArchivePost).to receive(:call)` or `expect(Posts::ArchivePost).to receive(:call).with(post)`. Let the action run, and check what the controller or job does, e.g. the records it changes, the response, the flash and the jobs it enqueues.
- To test how a request spec or job spec handles an action's `Error`, set up records that make the action fail for real. Never stub the action to raise it, e.g. `allow(Posts::ArchivePost).to receive(:call).and_raise(Posts::ArchivePost::Error)`.
