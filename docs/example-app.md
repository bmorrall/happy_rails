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
- **Post**: an article a user writes. Each post has an author, a magazine, a title, a body, a word count, a category and a status. The category is news, opinion or review. A post starts as a draft, and is published when it's ready. Only an App Admin or a Publishing Manager can feature a post, or file it under news.
- **Magazine**: a magazine the app publishes. Each post belongs to one. Users are added to a magazine as its editors. Each magazine has a name and an ISSN, e.g. `0317-8471`, and no two magazines share either.
- **Coauthorship**: a user the Author adds to a post as a Co-author, so they can edit it too.
- **Comment**: a reply to a published post. Comments belong to a post, and are approved before other readers see them.
- **Tag**: a label on a post, so readers can find related posts.
- **Publication**: a record of each time a post is published, and who published it.
- **LegacyUser**: a user in the database of the older system the app replaced. A user who hasn't been back since the switch is only there. Each has an email, and can have a secondary email.
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
  belongs_to :magazine

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
| Editors | Magazine Editor | Edit any post in the magazines they edit |
| Authors | Author | Edit the posts they wrote |
| Authors | Co-author | Edit the posts they were added to |
| Users | User | Read published posts, comment on them, and write posts |
| | Guest | Read published posts |

App Admin, Publishing Manager and Copy Editor are roles on the whole app. A Copy Editor's role only covers draft posts, and reviewing submitted posts. Magazine Editor is a role through membership of a parent record: a user is a Magazine Editor of the magazines they were added to as an editor, and the role covers every post in them. Author and Co-author are roles on one record: a user is the Author of the posts they wrote, and a Co-author of the posts they were added to, and of no others.

## Tasks

These are the tasks the examples use. Each one shows up on more than one page.

- **Write and edit a post.** Posts are written in Markdown. `MarkdownRenderer` turns Markdown into HTML and plain text with Commonmarker, and the `markdown_tag` helper shows a post's body as HTML on its page. Any user can write a post. The Author, a Co-author, a Magazine Editor of its magazine or an App Admin can edit it, and a Copy Editor can edit it while it's a draft. The routes are `GET /posts/new`, `POST /posts`, `GET /posts/:id/edit` and `PATCH /posts/:id`.
- **Bring over a legacy user.** When the app looks a user up by email, e.g. to add a Co-author to a post, it checks its own users first, by email or secondary email. If the user isn't there, `Users::ImportLegacyUser` copies them over from the legacy database.
- **Comment on a post.** A signed-in user can comment on a published post, with `POST /posts/:post_id/comments`.
- **Approve a comment.** The post's Author approves a comment with `POST /posts/:post_id/comments/:comment_id/approval`, so other readers can see it.
- **Live comments.** Readers who have a post open see a comment appear as soon as the Author approves it, without reloading the page.
- **Review a post.** The Author submits a draft for review. A Copy Editor then approves it, rejects it, or requests changes, which sends it back to a draft. A rejection needs a reason, which `RejectPostForm` asks for and the post saves as `rejection_reason`. The Copy Editor who approves it is saved as `approved_by`, and the one who rejects it as `rejected_by`. The routes are `POST /posts/:post_id/approval`, `GET /posts/:post_id/rejection/new`, `POST /posts/:post_id/rejection` and `POST /posts/:post_id/change_request`.
- **Publish a post.** A Publishing Manager or an App Admin publishes a post with `POST /posts/:post_id/publication`, and can unpublish it with `DELETE /posts/:post_id/publication`. The `Posts::PublishPost` action does the work.
- **Share a draft.** The Author can make a preview link for a draft post, with `POST /posts/:post_id/preview_link`, so others can read it before it's published. `SharePostForm` makes the link's token, and the post saves only a digest of it. The app shows the link once, right after it's made.
- **Schedule a post.** A post can be published at a later time. A Publishing Manager or an App Admin schedules a post with `POST /posts/:post_id/schedule`. The user who schedules it is saved as `scheduled_by`, and `PublishScheduledPostJob` publishes it at `publish_at`. A Publishing Manager can schedule several posts at once, and `Posts::EnqueuePublishes` enqueues a job for each one.
- **Archive a post.** `Posts::ArchivePost` archives an old post and locks its comments. `Posts::ArchivePosts` archives many posts at once, e.g. every post an author wrote.
- **Copy a post.** The Author can copy a post into a new draft. The caller builds the copy with `post.duplicate_post`, which sets its values, and `Posts::CopyPost` saves it with copies of its associations.
- **Check a post's links.** Before a post is published, the app checks the links in it. `Posts::RecordLinkCheck` saves the result on the post, with a report of each broken link in `link_check_report`, which the post's page lists.
- **Check a post against the style guide.** A Copy Editor checks a draft against the style guide, e.g. "email", not "e-mail". `StyleGuide` reads the style guide's word list from a CSV file saved in the repo, at `vendor/style_guide/words.csv`, and lists the corrections a post's body needs.
- **Send a newsletter.** A post goes out as a newsletter through an outside newsletter service, which has no gem, so `NewsletterClient` calls its HTTP API with Faraday. A newsletter is public, or private to paying subscribers. `Posts::SendPublicNewsletter` and `Posts::SendPrivateNewsletter` send a post as one or the other, through `NewsletterClient#create_public_newsletter` and `NewsletterClient#create_private_newsletter`, and share their errors through `Posts::NewsletterAction`. An editor can also set the newsletter's preheader, send time, reply-to address and tracking. Each newsletter goes to the "Weekly digest" list, which `NewsletterClient` looks up by name.
- **Manage newsletter subscribers.** A Publishing Manager adds readers to the "Weekly digest" list, and removes them, through `NewsletterClient#add_subscriber` and `NewsletterClient#remove_subscriber`. `NewsletterSubscribers::AddSubscriber` and `NewsletterSubscribers::RemoveSubscriber` share their errors through `NewsletterSubscribers::NewsletterAction`. `NewsletterSubscribers::ImportSubscribers` and `NewsletterSubscribers::ImportUnsubscribes` copy readers' subscriptions over from the legacy database, and share their errors through `NewsletterSubscribers::ImportAction`.
- **Notify subscribers.** When a post is published, `NotifySubscribersJob` delivers its newsletter with `NewsletterClient#deliver`.
- **Sync newsletter status.** `SyncNewslettersJob` keeps each post's newsletter status up to date. It reads the newsletters a page at a time with `NewsletterClient#list_newsletters`, one page per run.
- **Show newsletter stats.** A post's page shows the open rate of its newsletter, and the posts list shows it for each post that was sent. `NewsletterClient#fetch_stats` reads the stats for one newsletter, and `NewsletterClient#fetch_all_stats` reads them for many newsletters at once, keyed by newsletter ID. `Posts::EnqueueStatsRefresh` refreshes a post's stats by enqueueing `RefreshNewsletterStatsJob` with the post's newsletter ID.
- **Download a post as a PDF.** The Author can download a post as a PDF, with `GET /posts/:id.pdf`. `PostPdf` builds it with Prawn.
- **Back up a post.** When a post is published, `BackupPostJob` saves a copy of it to S3 through `PostBackupBucket`, a service around `Aws::S3::Client`.
- **Tell the mobile app.** When a post is published, `NotifyMobileAppJob` sends a message to the mobile app over MQTT, through `PostNotifier`, a service around the `mqtt` gem. `PostNotifier` publishes the post's title to the topic `posts/:id/published`. When someone reads the post in the mobile app, the mobile app sends a message to `posts/:id/read`, and `RecordPostReadsJob` reads those messages and adds them to the post's read count.
- **Clean up drafts.** `PurgeAbandonedDraftsJob` runs on a schedule and deletes drafts no one has touched in a long time.
