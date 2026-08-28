---
date: 2026-08-20
authors:
  - bernardo
categories:
  - Projects
tags:
  - portfolio
  - project-write-up
  - kotlin
  - android
  - ocr
  - language-learning
comments: true
---

# App7 — language learning from reading (project write-up)

!!! abstract "TL;DR"

    - a **Kotlin Multiplatform comic reader** (Android + desktop) where every speech bubble is a lesson.
    - **OCR-enriched pages**, tap-to-annotate tokens, machine-translation zoom.
    - built solo in **~5 months**, shipped behind a mechanical release gate.

<!-- more -->

## Why

Reading is the most pleasant way to acquire a language, but comics don't come
with a dictionary attached to the panel. App7 turns the comic page itself into
the interface: you tap the word inside the bubble, and the help comes to you —
in place, without leaving the story.

## The corpus

- **1.17M speech bubbles** auto-detected across **6,724 chapters / 119k page
  images** (14 series, 4 reading languages: de, fr, es, hi).
- **226 chapters OCR-enriched** into **127k word-level tokens**, each with its
  bounding box and confidence (Tesseract / PaddleOCR / vision-LLM pipeline).
- Machine translation with **OPUS-MT**: both a *meaning* translation and a
  *literal* one, with per-token source→target alignment — because learners
  need to know what the sentence means AND how it got there.

## The engineering

- **Compiled domain ported Haskell → C → Rust** behind a frozen 39-function C
  ABI: 58 Rust unit tests, a 100-assertion C round-trip parity oracle that
  passes unmodified (including a bit-exact xoshiro256** RNG), 25/25 Kotlin FFI
  parity tests, cross-built for 4 Android ABIs.
- **Cross-device sync** on a 12-table Turso schema — and a war story: the
  first version did ~1.6M cloud reads for 32 writes. A one-round-trip
  max-rowid watermark probe cut steady-state reads **~360×**
  (≈130k → ≈360 reads/hr), live-measured on device.
- **Ship discipline:** a 16-feature × 3-target requirements-traceability
  matrix enforced by a fail-closed gate that greps marker strings out of the
  actual APK/AppImage binaries and superset-diffs against a pinned baseline —
  110 logged automation runs over 14 Maestro e2e flows.

## The ML seam

Token suggestions ship today as a confidence-ranked v0 behind an explicit
interface (`TokenSuggestionScorer`). That seam is designed for my L1-aware
vocabulary-difficulty model (2nd place, closed track, BEA shared task @ ACL
2026): the same architecture that predicts which words are hard *for speakers
of your first language* will decide which token deserves your tap next.

## Links

- Code: *(repo being prepared — link coming here)*
- The BEA system: [Ensemble of Multilingual Encoders with NMT Augmentation
  for L1-Aware Vocabulary Difficulty Prediction](https://aclanthology.org/2026.bea-1.75/)
