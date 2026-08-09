---
layout: page
title: about
permalink: /about/
cmd: cat about.md
description: "Who runs this and what is on it."
---

I'm {{ site.author }} — {{ site.tagline }}.

This site is two things bolted together:

- **[articles/]({{ '/articles/' | relative_url }})** — write-ups and notes,
  authored in plain Markdown.
- **[files/]({{ '/files/' | relative_url }})** — scripts, configs and other
  artifacts, served raw over HTTPS.

## The files half

Anything under `raw/` in the [repository](https://github.com/{{ site.github_username }}/{{ site.github_username }}.github.io)
is published verbatim at `{{ site.url }}/raw/<path>`. Verbatim means it: no
front matter stripped, no templating applied, byte-identical to what is in git.
That is enforced by a check in CI, not by convention.

Every file also gets a preview page with syntax highlighting and its SHA-256
digest, and the whole set is published as
[SHA256SUMS.txt]({{ '/files/SHA256SUMS.txt' | relative_url }}) and
[manifest.json]({{ '/files/manifest.json' | relative_url }}).

A word on `curl … | sh`: the digests are there so you can check that what you
fetched is what I published. They cannot tell you the script is a good idea.
Read it first.

## Elsewhere

- [github.com/{{ site.github_username }}](https://github.com/{{ site.github_username }})
- [atom feed]({{ '/feed.xml' | relative_url }})
