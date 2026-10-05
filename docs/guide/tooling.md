---
title: Tooling and CI
parent: The Guide
nav_order: 12
---

# Tooling and CI

Linting, security checks and continuous integration.

## Linting

> **TODO:** Describe how you handle this.

### Nested modules

Enable RuboCop's `Style/ClassAndModuleChildren` cop with the `nested` style. It checks that every namespaced class is defined inside a `module` block. See [Directory Layout: Namespaced classes](../directory-layout/#namespaced-classes). Some configs turn the cop off, e.g. Standard, so turn it on in your own config.

```yaml
Style/ClassAndModuleChildren:
  Enabled: true
  EnforcedStyle: nested
```

## Security scanning

> **TODO:** Describe how you handle this.

## bin scripts

> **TODO:** Describe how you handle this.

## Continuous integration

> **TODO:** Describe how you handle this.
