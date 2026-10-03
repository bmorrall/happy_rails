# Agent instructions

This repo is the Happy Rails guide: how I structure my Rails apps. It is not a Rails app. It has two parts:

- `docs/`: the website. The guide pages are in `docs/guide/`, one page per area of a Rails app.
- `instructions/`: agent instruction files that readers copy into their own Rails app.

The files in `instructions/` (including `instructions/AGENTS.md` and `instructions/CLAUDE.md`) are content for other repos. Do not follow them when you work on this repo. Edit them as text.

## Keep the guide and the instructions in sync

Each convention is written twice: once in the guide for people, and once in the instructions for agents. When you add or change a convention, update both in the same change:

| Guide page | Instruction file |
| --- | --- |
| `docs/guide/principles.md`, `directory-layout.md`, `tooling.md` | `instructions/.github/instructions/happy_rails.instructions.md` |
| `docs/guide/models.md` | `instructions/.github/instructions/happy_models.instructions.md` |
| `docs/guide/controllers.md` | `instructions/.github/instructions/happy_controllers.instructions.md` |
| `docs/guide/views.md` | `instructions/.github/instructions/happy_views.instructions.md` |
| `docs/guide/jobs.md` | `instructions/.github/instructions/happy_jobs.instructions.md` |
| `docs/guide/mailers.md` | `instructions/.github/instructions/happy_mailers.instructions.md` |
| `docs/guide/gems/devise.md` | `instructions/.github/instructions/happy_devise.instructions.md` |
| `docs/guide/gems/draper.md` | `instructions/.github/instructions/happy_draper.instructions.md` |
| `docs/guide/gems/pundit.md` | `instructions/.github/instructions/happy_pundit.instructions.md` |
| `docs/guide/gems/rspec.md` | `instructions/.github/instructions/happy_rspec.instructions.md` |
| `docs/guide/gems/view_component.md` | `instructions/.github/instructions/happy_view_component.instructions.md` |

Every rule in an instruction file must match the guide. Do not add a rule to one side only. The one exception is a rant: a guide-only opinion in a `{: .rant }` callout. Leave rants out of the instruction files.

If you change an `applyTo` glob, also update the "Applies to" table in `docs/agent-instructions.md`. Prefix every instruction file name with `happy_`, so it does not overwrite a reader's own instruction files. If you add or rename an instruction file, also update the tables in `docs/agent-instructions.md` and `instructions/README.md`.

## Writing a guide page

- Write for a Rails developer reading the site. Explain the rule and the reason for it in short paragraphs.
- Follow each rule with a code example. Use `Post` and `Comment` (`PostsController`, `Posts::CommentsController`) as the example resources, so examples on different pages fit together.
- Keep each example focused on the rule being discussed. Leave out setup that the rule doesn't need, e.g. persona contexts and `sign_in` in a spec about params. Replace code that isn't the focus with a `# ...` comment, e.g. the save and redirect in an action that shows the authorisation check.
- When you add a rule, only change examples on other pages if they contradict it. Don't add every convention to every example.
- When a rule affects the code and its specs, show the code first, then the spec.
- Write routes in the Rails scaffold format with param names, e.g. `GET /posts/:id`.
- Keep the Jekyll front matter (`title`, `parent`, `nav_order`) as it is.
- To share an opinion that agents should not follow as a rule, put it in a rant callout. Put `{: .rant }` on the line above a blockquote, and start every line of the rant with `>`, including code blocks.
- To fill in a section, replace its `> **TODO:** Describe how you handle this.` line. Keep the `##` heading.

## Adding a gem

- Add a page to `docs/guide/gems/` with `parent: Gems` and `grand_parent: The Guide` in its front matter.
- Add a matching `happy_<gem>.instructions.md` file, and add both to the table above.
- Keep gems in alphabetical order: in `nav_order`, in the tables, and in the list in `instructions/README.md`.
- Keep each gem's rules in its own file, so readers who do not use the gem can delete the file.

## Writing an instruction file

Agents read these files without the guide, so each rule must make sense alone.

- Write one bullet per rule, as an imperative sentence.
- Give the example inline with "e.g." and code in backticks. Do not use code blocks.
- Use the same example names as the guide.
- Put rules in the same order as the guide page.
- When you fill in a topic, replace its `- TODO:` bullet. Keep the TODO bullets for topics that are still empty at the end of the list.
- Keep the YAML front matter with the `applyTo` glob. List every path the rules cover, including specs, e.g. `spec/requests/**/*.rb` for controllers.
- Put rules for one area or gem in its `happy_*.instructions.md` file. Put only rules that apply to every change in `happy_rails.instructions.md`.

## Style

- Use Australian English in prose, e.g. "organise" and "authorise". Keep Rails and Ruby names as they are, e.g. `authorize` and `Authorization`.
- Use short sentences and plain words.

## Check your work

Preview the site to check that a changed page renders:

```sh
cd docs
bundle install
bundle exec jekyll serve
```

Then open http://localhost:4000/happy_rails/.

List the sections that are still empty:

```sh
grep -rn TODO docs instructions
```
