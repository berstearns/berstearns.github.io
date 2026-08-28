---
date: 2026-08-20
authors:
  - bernardo
categories:
  - Projects
tags:
  - portfolio
  - project-write-up
  - browser-extension
  - machine-learning
  - recommender-systems
  - privacy
comments: true
---

# Hive Mind — a feed algorithm you own (project write-up)

**TL;DR:** 
- a browser extension that uses your recommendation system model to filter major feeds platforms.
- trained on your own annotations and from a small circle of people you trust. 
- all served on your computer

<!-- more -->

## Why

For anyone whose feed is decided by an engagement-optimized algorithm, the
hive mind is a recommendation system you own: it filters your feed on the
sites you already use, trained not by an ad market but by the judgments of a
small trusted circle.

## The architecture

A thin layer injected into the browser gives two primitives — *collect* and
*annotate* what you see. From there:

1. **In-page overlay** on major feeds (LinkedIn, X, Reddit): mark a post good
   or bad without leaving the page.
2. **Per-group training pipeline** in the cloud: each trusted circle gets its
   own ranker, trained only on that circle's annotations.
3. **Distribution back to the browser:** the ranker is distilled to a small
   ONNX model that scores posts **on-device** — feed data never leaves the
   browser to be ranked. Private by construction.
4. **The loop:** every correction you make is a training example for the next
   nightly retrain.

## The measurable outcomes (design targets)

The system is instrumented from day one for three numbers — these are the
targets the build must hit, and the dashboard will show them publicly:

- **Capture:** maximize good posts caught, under a hard bad-post leak
  threshold (a precision gate per circle).
- **Effort:** minimize feed-triage minutes per member per week — the model
  should work so you scroll less.
- **Sharing:** maximize the good knowledge that actually reaches the circle —
  what one member finds, all benefit from.

## Links

- Code: *(repo being prepared — link coming here)*
- Related: App7's feedback loop uses the same philosophy — deployed systems
  that keep improving through human corrections.
