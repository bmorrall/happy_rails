---
applyTo: "spec/helpers/**/*.rb,spec/requests/**/*.rb"
---

# View and helper specs

- Never write a view spec in `spec/views`. Cover branches in templates and partials with request specs, components with component specs, decorators with decorator specs, and helpers with helper specs.
- Give each helper that builds a simple view element a matcher for specs, e.g. `have_unknown_value_tag` for `unknown_value_tag`. See `happy_rspec.instructions.md`.
