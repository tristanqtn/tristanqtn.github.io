---
layout: page
title: about
permalink: /about/
cmd: cat about.md
description: "Who runs this and what is on it."
---

I'm {{ site.author }}. I work as a Purple Teamer, detection engineer, and incident response guy in a SOC. This is where I write about security research.

[articles/]({{ '/articles/' | relative_url }}) has write-ups and notes. [files/]({{ '/files/' | relative_url }}) has raw scripts and tools.

## About the files

Everything under `raw/` in the [repo](https://github.com/{{ site.github_username }}/{{ site.github_username }}.github.io) gets served verbatim at `{{ site.url }}/raw/<path>`. What you fetch is byte-for-byte what's in git.

Each file gets a preview page with syntax highlighting, and you can find SHA-256 hashes at [SHA256SUMS.txt]({{ '/files/SHA256SUMS.txt' | relative_url }}) to verify what you downloaded is what I published. (That said, a checksum can't tell you if a script is a good idea — always read it first.)

## Elsewhere

- [github.com/{{ site.github_username }}](https://github.com/{{ site.github_username }})
- [atom feed]({{ '/feed.xml' | relative_url }})
