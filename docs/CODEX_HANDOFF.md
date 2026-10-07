# CODEX_HANDOFF

Updated: 2026-10-07
Trigger phrase: **"chạy với codex"**

## Current snapshot
- Default branch: `main`
- Latest observed commit: `6c6c1195006955fca85bd2aeaf44386f700bb2bf`
- Project: AMD FirePro S9150/Hawaii compatibility work for llama.cpp Vulkan.
- Baseline: CPU correct; Vulkan full offload + Flash Attention ON corrupt; Flash Attention OFF correct at about 25 tok/s in the documented test.
- Experimental Hawaii patches may live on development branches; do not assume `main` is the active experiment branch.

## Codex execution contract
On **"chạy với codex"**, inspect all relevant branches/status/history first, reproduce the current baseline before changing GPU code, preserve local patches, use a task branch unless an existing experiment branch is explicitly selected, capture commands/results, and write `.ai/AI_REPORT.md`. Do not auto-merge `main`, force-push, or claim a fix without reproducible output validation.
