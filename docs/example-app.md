---
title: The Example App
nav_order: 2
permalink: /example-app/
---

# The Example App

Every example in the guide and the patterns comes from the same app: a small publishing app. Users write posts, editors publish them, and readers comment on them. Using one app means the examples on different pages fit together. A `Post` on the Models page is the same `Post` that the Actions page publishes and the Jobs page sends to subscribers.

This page describes the app, so you know what each example is talking about. The app isn't real, and its features only go as far as the examples need.

## Records

- **User**: someone who has signed in. A user can hold one role on the whole app, e.g. Publishing Manager.
- **Post**: an article a user writes. Each post has an author, a title, a body and a status. A post starts as a draft, and is published when it's ready.
- **Comment**: a reply to a published post. Comments belong to a post, and are approved before other readers see them.
- **Tag**: a label on a post, so readers can find related posts.
- **Publication**: a record of each time a post is published, and who published it.
- **NewsletterServiceIntegration**: the app's connection to the outside newsletter service, with its API key and base URL. An App Admin sets it up.

```ruby
class Post < ApplicationRecord
  enum :status, { draft: 0, published: 1 }

  belongs_to :author,
    class_name: "User"

  has_many :comments,
    dependent: :destroy
end
```

## Personas

The app has these personas, from the most access to the least. See [Principles: Personas](../guide/principles/#personas) for how personas are grouped and ranked.

| Group | Persona | Can |
| --- | --- | --- |
| App Admins | App Admin | Do anything |
| Editors | Publishing Manager | Publish any post |
| Editors | Copy Editor | Edit any post |
| Authors | Author | Edit the posts they wrote |
| Users | User | Read published posts, comment on them, and write posts |
| | Guest | Read published posts |

App Admin, Publishing Manager and Copy Editor are roles on the whole app. Author is a role on one record: a user is the Author of the posts they wrote, and of no others.

## Tasks

These are the tasks the examples use. Each one shows up on more than one page.

- **Write and edit a post.** Any user can write a post. The Author, a Copy Editor or an App Admin can edit it. The routes are `GET /posts/new`, `POST /posts`, `GET /posts/:id/edit` and `PATCH /posts/:id`.
- **Comment on a post.** A signed-in user can comment on a published post, with `POST /posts/:post_id/comments`.
- **Publish a post.** A Publishing Manager or an App Admin publishes a post with `POST /posts/:post_id/publication`, and can unpublish it with `DELETE /posts/:post_id/publication`. The `Posts::PublishPost` action does the work.
- **Share a draft.** The Author can make a preview link for a draft post, with `POST /posts/:post_id/preview_link`, so others can read it before it's published. `SharePostForm` makes the link's token, and the post saves only a digest of it. The app shows the link once, right after it's made.
- **Schedule a post.** A post can be published at a later time. The user who schedules it is saved as `scheduled_by`, and `PublishScheduledPostJob` publishes it at `publish_at`.
- **Archive a post.** `Posts::ArchivePost` archives an old post and locks its comments. `Posts::ArchivePosts` archives many posts at once, e.g. every post an author wrote.
- **Check a post's links.** Before a post is published, the app checks the links in it. `Posts::RecordLinkCheck` saves the result on the post.
- **Notify subscribers.** When a post is published, `NotifySubscribersJob` sends it to an outside newsletter service through `NewsletterClient`.
- **Show newsletter stats.** A post's page shows the open rate of its newsletter, and the posts list shows it for each post that was sent. `NewsletterClient#fetch_stats` reads the stats for one newsletter, and `NewsletterClient#fetch_all_stats` reads them for many newsletters at once, keyed by newsletter ID.
- **Clean up drafts.** `PurgeAbandonedDraftsJob` runs on a schedule and deletes drafts no one has touched in a long time.
