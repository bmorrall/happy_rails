---
title: Stored Data That No Longer Parses
parent: Patterns
nav_order: 9
---

# Stored Data That No Longer Parses

How to handle stored data that a struct no longer accepts, when [the model raises its own error](../../guide/models/#stored-data).

Some records save a struct as JSON, and turn it back into the struct when they read it. For example, `Posts::RecordLinkCheck` saves a report of each broken link in a post's `link_check_report` column, and `Post#parsed_link_check_report` reads it back as a `LinkCheckReport`.

```ruby
class LinkCheckReport < Dry::Struct
  attribute :broken_links, Types::Array do
    attribute :url, Types::String
    attribute :status, Types::Integer
  end
end
```

Say a later change adds a required `reason` to each broken link. Every new report has one, but the reports saved before the change don't. Reading one of them raises `Post::UnreadableDataError`, on every page, job and request that reads it, until the data is fixed.

The best time to deal with this is when the change ships. These patterns start there, and end with the safety net for data you missed.

## Keep old data readable

Change the struct so the old data still fits. Give the new attribute a default, or make it optional with `attribute?`, which lets the key be missing.

```ruby
class LinkCheckReport < Dry::Struct
  attribute :broken_links, Types::Array do
    attribute :url, Types::String
    attribute :status, Types::Integer
    attribute? :reason, Types::String.optional
  end
end
```

Nothing needs to change in the database, and nothing fails while the change rolls out. Use this whenever the code that reads the report can live without the new value, e.g. a page that shows the reason when it has one.

## Clear old data when the change ships

When the data is replaced often anyway, clear the rows that no longer fit, and let the app fill them again. A post's links are checked again before it is published, so a missing report only lasts until the next check.

Run a one-off job after the deploy. It reads each saved report, and clears the ones that raise.

```ruby
class ClearUnreadableLinkCheckReportsJob < ApplicationJob
  queue_as :low

  def perform
    Post.where.not(link_check_report: nil).find_each do |post|
      post.parsed_link_check_report
    rescue Post::UnreadableDataError
      post.update!(link_check_report: nil)
    end
  end
end
```

The job reads each report through the model, so it clears exactly the rows that the rest of the app can't read. Clear a value only when losing it is safe. A report that nothing will replace, e.g. on a post that is already published, is lost for good.

## Fill in old data when the change ships

When the new value can be worked out for the old rows, write it in, so they fit again. Run it in a one-off job, as above, and work on the stored hash, not the struct. The struct can't read the old data, which is why you're running the job.

```ruby
class AddReasonToLinkCheckReportsJob < ApplicationJob
  queue_as :low

  def perform
    Post.where.not(link_check_report: nil).find_each do |post|
      report = post.link_check_report.deep_dup
      report["broken_links"].each { |link| link["reason"] ||= "HTTP #{link["status"]}" }

      post.update!(link_check_report: report)
    end
  end
end
```

This keeps every report, so use it when the data can't be replaced.

## Rescue the error where it's read

Any of the patterns above can miss a row, e.g. a report saved by a request that was still running on the old code during the deploy. Each caller that reads the data then rescues the model's error, and decides what to do.

A page that can show the post without its report rescues the error, reports it, and carries on with `nil`. Read the value in a private method, as in [Values from Services: Assign it in the action](../values-from-services/#assign-it-in-the-action).

```ruby
class PostsController < ApplicationController
  # GET /posts/:id
  def show
    @link_check_report = read_link_check_report
  end

  private

  def read_link_check_report
    @post.parsed_link_check_report
  rescue Post::UnreadableDataError => e
    Honeybadger.notify(e, context: { post: @post&.to_honeybadger_context })
    nil
  end
end
```

The report goes out from the controller, which rescued the error, and not from the model. See [Honeybadger: Reporting errors](../../guide/gems/honeybadger/#reporting-errors).

Code that can't carry on without the data lets the error raise, e.g. a job that emails the Author a list of the broken links. Honeybadger then reports it as it would any other error.

### Put the stored data in the report

The stored data is the most useful thing to see when you debug the error. Give the model's error the column and its value, and add them to the report with `to_honeybadger_context`. See [Honeybadger: Errors](../../guide/gems/honeybadger/#errors).

```ruby
class Post < ApplicationRecord
  ### Constants ###

  class UnreadableDataError < StandardError
    def initialize(message = nil, column: nil, value: nil)
      super(message)
      @column = column
      @value = value
    end

    def to_honeybadger_context
      {
        stored_data_column: column,
        stored_data_value: value&.to_json&.truncate(1_000)
      }
    end

    private

    attr_reader :column, :value
  end

  # ...

  ### Public Methods ###

  concerning :LinkChecks do
    def parsed_link_check_report
      return if link_check_report.blank?

      LinkCheckReport.new(link_check_report.deep_symbolize_keys)
    rescue Dry::Struct::Error => e
      raise UnreadableDataError.new(e.message, column: "link_check_report", value: link_check_report)
    end
  end
end
```

The value is a nested hash, so turn it into a JSON string. The context then stays flat, as [Honeybadger: Context](../../guide/gems/honeybadger/#context) asks, and you can still read and search it. Start the keys with `stored_data_`, so they don't clash with the records in the report's context. Cut the value short, so a large value doesn't fill the report. Leave out any value that holds data you'd need to keep safe.

The error's message comes from the struct, and says which attribute failed, e.g. that `reason` is missing.

## Some things to know

- Every caller that reads the row reports the error, every time it reads it, until the data is fixed. A busy page can send many reports for one row. See [Repeated Error Reports](../repeated-error-reports/) for ways to send fewer.
- Test a struct change against data saved by the old struct, e.g. a spec that builds the struct from a hash in the old shape. Then a change that would make old data fail fails in your specs first.
- When the data comes from outside the app, e.g. a payload another system sends, the new struct might also reject new data. The code that parses it reports that first. The read only fails for data saved before the change.
