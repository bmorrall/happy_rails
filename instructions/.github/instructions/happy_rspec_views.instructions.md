---
applyTo: "spec/helpers/**/*.rb,spec/requests/**/*.rb"
---

# View and helper specs

- You MUST NOT write a view spec in `spec/views`. Cover branches in templates and partials with request specs, components with component specs, decorators with decorator specs, and helpers with helper specs.
- Give each helper that builds a simple view element a matcher for specs, e.g. `have_unknown_value_tag` for `unknown_value_tag`. See `happy_rspec.instructions.md`.
- In request specs, check a form field that only some users can set for a persona who can set it and one who can't, with a helper named after the field that wraps `have_field` and passes Capybara's options through, defined at the bottom of the spec file, e.g. `def have_featured_field(**options) = have_field("Featured", **options)`. Use it for both checks, e.g. `expect(response.body).to have_featured_field` as a Publishing Manager and `expect(response.body).not_to have_featured_field` as an Author on `GET /posts/:id/edit`, or `have_featured_field(disabled: true)` when the form disables the field.
