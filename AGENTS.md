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

Every rule in an instruction file must match the guide. Do not add a rule to one side only.

If you change an `applyTo` glob, also update the "Applies to" table in `docs/agent-instructions.md`. Prefix every instruction file name with `happy_`, so it does not overwrite a reader's own instruction files. If you add or rename an instruction file, also update the tables in `docs/agent-instructions.md` and `instructions/README.md`.

## Writing a guide page

- Write for a Rails developer reading the site. Explain the rule and the reason for it in short paragraphs.
- Follow each rule with a code example. Use `Post` and `Comment` (`PostsController`, `Posts::CommentsController`) as the example resources, so examples on different pages fit together.
- When a rule affects the code and its specs, show the code first, then the spec.
- Write routes in the Rails scaffold format with param names, e.g. `GET /posts/:id`.
- Keep the Jekyll front matter (`title`, `parent`, `nav_order`) as it is.
- To fill in a section, replace its `> **TODO:** Describe how you handle this.` line. Keep the `##` heading.

## Writing an instruction file

Agents read these files without the guide, so each rule must make sense alone.

- Write one bullet per rule, as an imperative sentence.
- Give the example inline with "e.g." and code in backticks. Do not use code blocks.
- Use the same example names as the guide.
- Put rules in the same order as the guide page.
- When you fill in a topic, replace its `- TODO:` bullet. Keep the TODO bullets for topics that are still empty at the end of the list.
- Keep the YAML front matter with the `applyTo` glob. List every path the rules cover, including specs, e.g. `spec/requests/**/*.rb` for controllers.
- Put rules for one area in its `happy_*.instructions.md` file. Put only rules that apply to every change in `happy_rails.instructions.md`.

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
