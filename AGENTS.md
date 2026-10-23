# Agent instructions

This repo is the Happy Rails guide: how I structure my Rails apps. It is not a Rails app. It has two parts:

- `docs/`: the website. The guide pages are in `docs/guide/`, one page per area of a Rails app. The testing pages are in `docs/testing/`, the RSpec counterpart of each guide page. The pattern pages are in `docs/patterns/`, one page per problem.
- `instructions/`: agent instruction files that readers copy into their own Rails app.

The files in `instructions/` (including `instructions/AGENTS.md` and `instructions/CLAUDE.md`) are content for other repos. Do not follow them when you work on this repo. Edit them as text.

## Keep the guide and the instructions in sync

Each convention is written twice: once in the guide or testing pages for people, and once in the instructions for agents. When you add or change a convention, update both in the same change:

| Page | Instruction file |
| --- | --- |
| `docs/guide/principles.md`, `directory-layout.md`, `tooling.md` | `instructions/.github/instructions/happy_rails.instructions.md` |
| `docs/guide/models.md` | `instructions/.github/instructions/happy_models.instructions.md` |
| `docs/guide/validators.md` | `instructions/.github/instructions/happy_validators.instructions.md` |
| `docs/guide/forms.md` | `instructions/.github/instructions/happy_forms.instructions.md` |
| `docs/guide/actions.md` | `instructions/.github/instructions/happy_actions.instructions.md` |
| `docs/guide/services.md` | `instructions/.github/instructions/happy_services.instructions.md` |
| `docs/guide/jobs.md` | `instructions/.github/instructions/happy_jobs.instructions.md` |
| `docs/guide/controllers.md` | `instructions/.github/instructions/happy_controllers.instructions.md` |
| `docs/guide/views.md` | `instructions/.github/instructions/happy_views.instructions.md` |
| `docs/guide/mailers.md` | `instructions/.github/instructions/happy_mailers.instructions.md` |
| `docs/guide/code-style.md` | `instructions/.github/instructions/happy_style.instructions.md` |
| `docs/guide/gems/aasm.md` | `instructions/.github/instructions/happy_aasm.instructions.md` |
| `docs/guide/gems/devise.md` | `instructions/.github/instructions/happy_devise.instructions.md` |
| `docs/guide/gems/draper.md` | `instructions/.github/instructions/happy_draper.instructions.md` |
| `docs/guide/gems/dry_rb.md` | `instructions/.github/instructions/happy_dry_rb.instructions.md` |
| `docs/guide/gems/honeybadger.md` | `instructions/.github/instructions/happy_honeybadger.instructions.md` |
| `docs/guide/gems/pundit.md` | `instructions/.github/instructions/happy_pundit.instructions.md` |
| `docs/guide/gems/simple_form.md` | `instructions/.github/instructions/happy_simple_form.instructions.md` |
| `docs/guide/gems/turbo.md` | `instructions/.github/instructions/happy_turbo.instructions.md` |
| `docs/guide/gems/view_component.md` | `instructions/.github/instructions/happy_view_component.instructions.md` |
| `docs/guide/gems/wisper.md` | `instructions/.github/instructions/happy_wisper.instructions.md` |
| `docs/testing/principles.md`, `directory-layout.md`, `gems/rspec.md` | `instructions/.github/instructions/happy_rspec.instructions.md` |
| `docs/testing/models.md` | `instructions/.github/instructions/happy_rspec_models.instructions.md` |
| `docs/testing/validators.md` | `instructions/.github/instructions/happy_rspec_validators.instructions.md` |
| `docs/testing/forms.md` | `instructions/.github/instructions/happy_rspec_forms.instructions.md` |
| `docs/testing/actions.md` | `instructions/.github/instructions/happy_rspec_actions.instructions.md` |
| `docs/testing/services.md` | `instructions/.github/instructions/happy_rspec_services.instructions.md` |
| `docs/testing/jobs.md` | `instructions/.github/instructions/happy_rspec_jobs.instructions.md` |
| `docs/testing/controllers.md` | `instructions/.github/instructions/happy_rspec_controllers.instructions.md` |
| `docs/testing/views.md` | `instructions/.github/instructions/happy_rspec_views.instructions.md` |
| `docs/testing/mailers.md` | `instructions/.github/instructions/happy_rspec_mailers.instructions.md` |
| `docs/testing/code-style.md` | `instructions/.github/instructions/happy_rspec_style.instructions.md` |
| `docs/testing/gems/aasm.md` | `instructions/.github/instructions/happy_rspec_aasm.instructions.md` |
| `docs/testing/gems/devise.md` | `instructions/.github/instructions/happy_rspec_devise.instructions.md` |
| `docs/testing/gems/draper.md` | `instructions/.github/instructions/happy_rspec_draper.instructions.md` |
| `docs/testing/gems/dry_rb.md` | `instructions/.github/instructions/happy_rspec_dry_rb.instructions.md` |
| `docs/testing/gems/honeybadger.md` | `instructions/.github/instructions/happy_rspec_honeybadger.instructions.md` |
| `docs/testing/gems/pundit.md` | `instructions/.github/instructions/happy_rspec_pundit.instructions.md` |
| `docs/testing/gems/shoulda_matchers.md` | `instructions/.github/instructions/happy_rspec_shoulda_matchers.instructions.md` |
| `docs/testing/gems/simple_form.md` | `instructions/.github/instructions/happy_rspec_simple_form.instructions.md` |
| `docs/testing/gems/turbo.md` | `instructions/.github/instructions/happy_rspec_turbo.instructions.md` |
| `docs/testing/gems/view_component.md` | `instructions/.github/instructions/happy_rspec_view_component.instructions.md` |
| `docs/testing/gems/webmock.md` | `instructions/.github/instructions/happy_rspec_webmock.instructions.md` |
| `docs/testing/gems/wisper.md` | `instructions/.github/instructions/happy_rspec_wisper.instructions.md` |

Every rule in an instruction file must match its page. Do not add a rule to one side only. The one exception is a rant: a guide-only opinion in a `{: .rant }` callout. Leave rants out of the instruction files.

`docs/guide/code-style.md` holds my own style preferences. They are optional, so readers can delete `happy_style.instructions.md`. Its testing page, `docs/testing/code-style.md`, holds the style preferences for specs, in `happy_rspec_style.instructions.md`. Rules for agents only go in its "For agents" section, as a short line each, so the guide still lists every rule in the file.

If you change an `applyTo` glob, also update the "Applies to" tables in `docs/agent-instructions.md`. Prefix every instruction file name with `happy_`, so it does not overwrite a reader's own instruction files. If you add or rename an instruction file, also update the tables in `docs/agent-instructions.md` and `instructions/README.md`.

## Testing pages

Each guide page has a testing counterpart at the same path under `docs/testing/`, e.g. `docs/guide/actions.md` and `docs/testing/actions.md`. The guide covers the app's code. The testing page covers its specs, written for RSpec. Each instruction file has a matching `happy_rspec_*` file, e.g. `happy_rspec_actions.instructions.md`, so readers who don't use RSpec can delete them.

- Put a rule about specs on the testing page and in the `happy_rspec_*` file, e.g. how to name `describe` blocks, what to stub, and spec matchers. Put the app-code rule on the guide page. When a rule affects both, split it.
- A sentence that only gives specs as a reason for an app-code rule stays in the guide, e.g. "so a missing check fails in your specs".
- Keep the guide page's `## Testing` heading, with one line linking to its testing page.
- Give a testing page the same `title` and `nav_order` as its guide page, with `parent: Testing`, or `parent: Gems` and `grand_parent: Testing` for a gem. Name its sections after the guide sections they test, in the guide's order.
- Give a `happy_rspec_*` file only `spec/` paths in its `applyTo`, and leave `spec/` paths out of the main file.

## The setup skill

Steps an agent does once, when it sets up the app, go in the `happy-rails-setup` skill in `instructions/.github/skills/happy-rails-setup/`, not in the instruction files. A setup step writes a base class, a shared concern, an initialiser, a config setting or a file in `spec/support`, e.g. `ApplicationAction` or `config.include ActiveJob::TestHelper, type: :job`. Rules that apply each time an agent writes code stay in the instruction files, e.g. "Inherit every action from `ApplicationAction`".

- When a rule mixes both, split it: the setup part goes in the skill, and the instruction file keeps the part an agent follows each time, e.g. "Never add `verify_authorized` to individual controllers".
- Put each area's or gem's steps in `references/<name>.md`, named after the area or gem, e.g. `references/pundit.md`. Start the file with a `Rules:` line naming the instruction files for its steps, e.g. `` Rules: `.github/instructions/happy_pundit.instructions.md` ``. Follow the order of the pages that match those files in the table above. Add the file to the table in `SKILL.md`, with when to run it.
- Put each file the steps write in `assets/`, at the same path it has in the app, e.g. `assets/app/actions/application_action.rb`. Copy the code from the guide's example, without the path comment. When the guide's code changes, update the asset in the same change.
- Every step in the skill must match the guide, like the instruction files.

## Writing a guide page

- Write for a Rails developer reading the site. Explain the rule and the reason for it in short paragraphs.
- Follow each rule with a code example. Use `Post` and `Comment` (`PostsController`, `Posts::CommentsController`) as the example resources, so examples on different pages fit together. They come from the publishing app described in `docs/example-app.md`. Take the records, personas and tasks for new examples from that page. If an example needs something the app doesn't have yet, add it to that page first. Keep the addition small, and keep it in the same publishing domain.
- Keep each example focused on the rule being discussed. Leave out setup that the rule doesn't need, e.g. persona contexts and `sign_in` in a spec about params. Replace code that isn't the focus with a `# ...` comment, e.g. the save and redirect in an action that shows the authorisation check.
- When you add a rule, only change examples on other pages if they contradict it. Don't add every convention to every example.
- When a rule affects the code and its specs, show the code on the guide page and the spec on the testing page. Link between them.
- Write routes in the Rails scaffold format with param names, e.g. `GET /posts/:id`.
- Keep the Jekyll front matter (`title`, `parent`, `nav_order`) as it is.
- To share an opinion that agents should not follow as a rule, put it in a rant callout. Put `{: .rant }` on the line above a blockquote, and start every line of the rant with `>`, including code blocks.
- To fill in a section, replace its `> **TODO:** Describe how you handle this.` line. Keep the `##` heading.

## Writing a pattern page

A pattern page shows ways to solve one problem within the guide's rules, e.g. getting a value back from an action. Patterns are suggestions, not rules, so they have no instruction file. Do not copy a pattern page into the instruction files.

When agents should follow a pattern by default, write it as a rule in the guide page it helps with, and link to the pattern page for the details. Then add the rule to that page's instruction file as usual, with the pattern page's full URL, e.g. `https://bmorrall.github.io/happy_rails/patterns/values-from-actions/`.

- Add the page to `docs/patterns/` with `parent: Patterns` in its front matter.
- Name the page after the problem, not one solution, e.g. "Values from Actions".
- Show each solution in its own `##` section, with the same example names as the guide.
- Link to the pattern from the guide section it helps with.

## Adding a gem

- Add a page to `docs/guide/gems/` with `parent: Gems` and `grand_parent: The Guide` in its front matter.
- Add a matching `happy_<gem>.instructions.md` file, and add both to the table above. If the gem has setup steps, also add them to the setup skill.
- Add its testing page to `docs/testing/gems/` with `parent: Gems` and `grand_parent: Testing`, and a matching `happy_rspec_<gem>.instructions.md` file. A gem used only in specs, e.g. WebMock, has only the testing page and the `happy_rspec_` file.
- Keep gems in alphabetical order: in `nav_order`, in the tables, and in the list in `instructions/README.md`.
- Keep each gem's rules in its own file, so readers who do not use the gem can delete the file.

## Writing an instruction file

Agents read these files without the guide, so each rule must make sense alone.

- Write one bullet per rule, as an imperative sentence.
- Give the example inline with "e.g." and code in backticks. Do not use code blocks.
- Use the same example names as the guide.
- Put rules in the same order as the guide page.
- When you fill in a topic, replace its `- TODO:` bullet. Keep the TODO bullets for topics that are still empty at the end of the list.
- Keep the YAML front matter with the `applyTo` glob. List every path the rules cover. Spec paths go in the `happy_rspec_*` file, e.g. `spec/requests/**/*.rb` in `happy_rspec_controllers`.
- Put rules for one area or gem in its `happy_*.instructions.md` file. Put only rules that apply to every change in `happy_rails.instructions.md`.

## Style

- Use Australian English in prose, e.g. "organise" and "authorise". Keep Rails and Ruby names as they are, e.g. `authorize` and `Authorization`.
- Use short sentences and plain words.
- On guide and testing pages and in instruction files, write a rule with no exceptions as a plain imperative, and a prohibition with "MUST NOT" in capitals, e.g. "You MUST NOT use `permit!`", not "Never" or "Don't". Do not write "MUST" or "must". Write "SHOULD" and "SHOULD NOT" in capitals for a default, and "MAY" in capitals for something allowed but not required, as defined in `docs/guide/principles.md`. Never write "should" or "may" in lowercase. Use other words, e.g. "can", "might", "needs to" or "has to". Give a rule the same word on its page and in its instruction file.

## Check your work

Preview the site to check that a changed page renders:

```sh
cd docs
bundle install
bundle exec jekyll serve
```

Then open http://localhost:4000/happy_rails/.

Check the links between pages. CI runs the same check on every push and pull request:

```sh
cd docs
bundle exec jekyll build --baseurl ""
bundle exec htmlproofer _site --disable-external
```

List the sections that are still empty:

```sh
grep -rn TODO docs instructions
```
