# OpenAI Evaluator Runs Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable real OpenAI-backed evaluator runs in parallel with partial results in `/evaluate`.

**Architecture:** Add a tiny shared OpenAI HTTP client and a shared evaluator prompt/validation helper, then run evaluator classes concurrently in Sinatra using threads. Preserve evaluator-level ownership while returning stable JSON for UI rendering.

**Tech Stack:** Ruby, Sinatra, Net::HTTP, Minitest

---

### Task 1: Add failing API contract tests
**Files:**
- Modify: `test/app_test.rb`

### Task 2: Add OpenAI client and shared evaluator helper
**Files:**
- Create: `lib/openai_client.rb`
- Create: `lib/evaluators/base.rb`

### Task 3: Convert evaluator stubs to OpenAI-backed evaluators
**Files:**
- Modify: `lib/evaluators/strategy.rb`
- Modify: `lib/evaluators/vision.rb`
- Modify: `lib/evaluators/jtbd.rb`
- Modify: `lib/evaluators/user_flows.rb`
- Modify: `lib/evaluators/product_charter.rb`
- Modify: `lib/evaluators/feedback.rb`

### Task 4: Run evaluators in parallel threads with partial results
**Files:**
- Modify: `app.rb`

### Task 5: Update UI summary message to partial-result contract
**Files:**
- Modify: `public/app.js`

### Task 6: Verify syntax/tests available in environment
**Files:**
- No code changes
