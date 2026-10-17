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
- **Post**: an article a user writes. Each post has an author, a title, a body, a category and a status. The category is news, opinion or review. A post starts as a draft, and is published when it's ready. Only an App Admin or a Publishing Manager can feature a post, or file it under news.
- **Coauthorship**: a user the Author adds to a post as a Co-author, so they can edit it too.
- **Comment**: a reply to a published post. Comments belong to a post, and are approved before other readers see them.
- **Tag**: a label on a post, so readers can find related posts.
- **Publication**: a record of each time a post is published, and who published it.
- **NewsletterServiceIntegration**: the app's connection to the outside newsletter service, with its API key and base URL. An App Admin sets it up.

```ruby
class Post < ApplicationRecord
  enum :status, {
    draft: "draft",
    submitted: "submitted",
    approved: "approved",
    rejected: "rejected",
    published: "published"
  }
  enum :category, { news: "news", opinion: "opinion", review: "review" }

  belongs_to :author,
    class_name: "User"

  has_many :comments,
    dependent: :destroy

  has_many :coauthorships,
    dependent: :destroy
  has_many :coauthors,
    through: :coauthorships,
    source: :user
end
```

```ruby
class User < ApplicationRecord
  has_many :coauthorships,
    dependent: :destroy
  has_many :coauthored_posts,
    through: :coauthorships,
    source: :post
end
```

## Personas

The app has these personas, from the most access to the least. See [Principles: Personas](../guide/principles/#personas) for how personas are grouped and ranked.

| Group | Persona | Can |
| --- | --- | --- |
| App Admins | App Admin | Do anything |
| Editors | Publishing Manager | Publish any post |
| Editors | Copy Editor | Edit draft posts, and review submitted posts |
| Authors | Author | Edit the posts they wrote |
| Authors | Co-author | Edit the posts they were added to |
| Users | User | Read published posts, comment on them, and write posts |
| | Guest | Read published posts |

App Admin, Publishing Manager and Copy Editor are roles on the whole app. A Copy Editor's role only covers draft posts, and reviewing submitted posts. Author and Co-author are roles on one record: a user is the Author of the posts they wrote, and a Co-author of the posts they were added to, and of no others.

## Tasks

These are the tasks the examples use. Each one shows up on more than one page.

- **Write and edit a post.** Any user can write a post. The Author, a Co-author or an App Admin can edit it, and a Copy Editor can edit it while it's a draft. The routes are `GET /posts/new`, `POST /posts`, `GET /posts/:id/edit` and `PATCH /posts/:id`.
- **Comment on a post.** A signed-in user can comment on a published post, with `POST /posts/:post_id/comments`.
- **Approve a comment.** The post's Author approves a comment with `POST /posts/:post_id/comments/:comment_id/approval`, so other readers can see it.
- **Live comments.** Readers who have a post open see a comment appear as soon as the Author approves it, without reloading the page.
- **Review a post.** The Author submits a draft for review. A Copy Editor then approves it, rejects it, or requests changes, which sends it back to a draft. A rejection needs a reason, which `RejectPostForm` asks for and the post saves as `rejection_reason`. The Copy Editor who approves it is saved as `approved_by`, and the one who rejects it as `rejected_by`. The routes are `POST /posts/:post_id/approval`, `GET /posts/:post_id/rejection/new`, `POST /posts/:post_id/rejection` and `POST /posts/:post_id/change_request`.
- **Publish a post.** A Publishing Manager or an App Admin publishes a post with `POST /posts/:post_id/publication`, and can unpublish it with `DELETE /posts/:post_id/publication`. The `Posts::PublishPost` action does the work.
- **Share a draft.** The Author can make a preview link for a draft post, with `POST /posts/:post_id/preview_link`, so others can read it before it's published. `SharePostForm` makes the link's token, and the post saves only a digest of it. The app shows the link once, right after it's made.
- **Schedule a post.** A post can be published at a later time. The user who schedules it is saved as `scheduled_by`, and `PublishScheduledPostJob` publishes it at `publish_at`. A Publishing Manager can schedule several posts at once, and `Posts::EnqueuePublishes` enqueues a job for each one.
- **Archive a post.** `Posts::ArchivePost` archives an old post and locks its comments. `Posts::ArchivePosts` archives many posts at once, e.g. every post an author wrote.
- **Copy a post.** The Author can copy a post into a new draft. The caller builds the copy with `post.duplicate_post`, which sets its values, and `Posts::CopyPost` saves it with copies of its associations.
- **Check a post's links.** Before a post is published, the app checks the links in it. `Posts::RecordLinkCheck` saves the result on the post.
- **Notify subscribers.** When a post is published, `NotifySubscribersJob` sends it to an outside newsletter service through `NewsletterClient`. Once `NewsletterClient` gets too big, it makes its HTTP calls through `NewsletterGateway`, a plain Ruby class in `lib/`. A newsletter is public, or private to paying subscribers: `NewsletterClient#create_public_newsletter` and `NewsletterClient#create_private_newsletter` both create one through `NewsletterGateway#create_newsletter`, with a different visibility. `NewsletterClient#list_newsletters` reads the newsletters one page at a time, and `SyncNewslettersJob` works through them a page per run, to keep each post's newsletter status up to date.
- **Show newsletter stats.** A post's page shows the open rate of its newsletter, and the posts list shows it for each post that was sent. `NewsletterClient#fetch_stats` reads the stats for one newsletter, and `NewsletterClient#fetch_all_stats` reads them for many newsletters at once, keyed by newsletter ID. `Posts::EnqueueStatsRefresh` refreshes a post's stats by enqueueing `RefreshNewsletterStatsJob` with the post's newsletter ID.
- **Back up a post.** When a post is published, `BackupPostJob` saves a copy of it to S3 through `PostBackupBucket`, a service around `Aws::S3::Client`.
- **Clean up drafts.** `PurgeAbandonedDraftsJob` runs on a schedule and deletes drafts no one has touched in a long time.
