# tristanqtn.github.io

Source for <https://tristanqtn.github.io>. Two halves:

- **`_articles/`** — write-ups in plain Markdown, rendered with syntax
  highlighting at `/articles/<slug>/`.
- **`raw/`** — scripts, configs and other artifacts, served **byte-identical**
  at `/raw/<path>`, each with a preview page at `/files/<path>.html`.

Jekyll 4, built by GitHub Actions (not Pages' native build — that runs in safe
mode with `_plugins/` disabled, and the plugins are what make `raw/` work).

## Publishing a file

```bash
cp ~/bin/enum.sh raw/scripts/
git add raw/scripts/enum.sh && git commit -m 'add enum.sh' && git push
```

That's the whole workflow. On push it is served at:

```
https://tristanqtn.github.io/raw/scripts/enum.sh
```

and indexed automatically at [`/files/`](https://tristanqtn.github.io/files/)
with its size, line count, detected language, SHA-256 and a highlighted
preview. No registration step, no manifest to edit.

**Verbatim means verbatim.** `raw/` is excluded from Jekyll's reader entirely;
`_plugins/raw_files.rb` registers each file as a `Jekyll::StaticFile`, which is
copied with `FileUtils.copy_file`. Nothing is sniffed for front matter, nothing
goes through Liquid. A YAML config starting with `---`, a Helm chart full of
template delimiters, a CRLF PowerShell script and a binary all survive intact.
CI re-checks that on every deploy:

```yaml
- run: diff -r --no-dereference raw _site/raw   # fails the build if anything differs
```

Digests for everything are published at
[`/files/SHA256SUMS.txt`](https://tristanqtn.github.io/files/SHA256SUMS.txt)
(consumable by `sha256sum -c`) and
[`/files/manifest.json`](https://tristanqtn.github.io/files/manifest.json).

```bash
curl -fsSL https://tristanqtn.github.io/files/SHA256SUMS.txt > SHA256SUMS
curl -fsSL https://tristanqtn.github.io/raw/scripts/enum.sh -o scripts/enum.sh
sha256sum -c --ignore-missing SHA256SUMS
```

## Writing an article

Drop a Markdown file in `_articles/` — no date in the filename:

```yaml
---
title:       "Reversing a CTF cookie exfil"
date:        2026-08-09 14:30:00 +0200   # required; the build fails without it
description: "One-line summary, used for SEO and the listing."
tags:        [ctf, web]
draft:       false                        # true -> local only
---
```

Tag pages under `/tags/<slug>/` are generated from whatever tags exist. Drafts
are visible locally and stripped from production builds — removed from the
collection, so no page is ever written to a guessable URL.

## Local development

Everything runs in Docker; no Ruby needed on the host.

```bash
./site install    # install gems into vendor/bundle
./site serve      # http://localhost:4000, live reload, drafts visible
./site stop       # stop a detached dev server
./site build      # production build into _site/
./site check      # build, then verify raw/ round-trips byte-for-byte
```

Three things that will otherwise cost you ten minutes:

1. **`_plugins/*.rb` is not hot-reloaded.** It's `require`d once at boot;
   editing it while `serve` is running is a silent no-op. Restart.
2. **`raw/` is not watched.** It's in `exclude:`, so the file watcher ignores
   it — adding a file there does not trigger a rebuild. Restart, or use
   `./site build`. This is the price of the byte-identity guarantee.
3. **Never use `--incremental` or `--safe`.** The first caches at page
   granularity and doesn't understand generator-produced pages; the second
   disables `_plugins/` outright.

## Layout

```
_plugins/raw_files.rb   walks raw/, registers static files, builds previews
_plugins/articles.rb    date validation, draft stripping
_plugins/tag_pages.rb   generates /tags/<slug>/
_layouts/               default, page, article, file, tag
assets/css/main.css     the terminal skin; palette is all custom properties
assets/css/rouge.css    syntax colours, var()-driven so light/dark is free
raw/                    hosted files — excluded from Jekyll, served verbatim
```
