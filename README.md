# Happy Rails

How I structure my Rails apps, published as a static site at https://bmorrall.github.io/happy_rails/, plus agent instruction files you can copy into your own repo.

## Layout

- `docs/`: the website, written in Markdown and built by GitHub Pages with Jekyll and the [Just the Docs](https://just-the-docs.com) theme.
- `instructions/`: files to copy into a Rails app so coding agents follow the same conventions. See [instructions/README.md](instructions/README.md).

When you change a convention, update both the guide page in `docs/guide/` and the matching file in `instructions/.github/instructions/`.

## Publishing

In the repo on GitHub, go to **Settings → Pages**, set **Source** to **Deploy from a branch**, and choose `main` and `/docs`.

## Preview locally

```sh
cd docs
bundle install
bundle exec jekyll serve
```

Then open http://localhost:4000/happy_rails/.

## Finding unfinished content

```sh
grep -rn TODO docs instructions
```
