---
title: "An unfinished thought"
date: 2026-08-07 09:00:00 +0200
description: "Drafts are visible locally and stripped from production builds."
tags: [meta]
draft: true
---

This article has `draft: true` in its front matter.

It shows up when you run `./site serve` locally, and it is removed from the
collection entirely during a production build — not hidden by a template
filter, but never written to `_site` at all, so there is no orphan page sitting
at a guessable URL.

Delete this file once the point has been made.
