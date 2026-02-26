# OpenAI Evaluator Runs Design

Date: 2026-02-26
Topic: Parallel per-evaluator OpenAI execution with partial results

## Decisions
- Use individual evaluator functions/classes (no combined mega-evaluator prompt).
- Execute evaluators in parallel using Ruby threads.
- Return partial results: successful evaluator outputs plus per-agent error objects.
- Skip overall orchestrator scoring for this phase.

## Runtime Flow
1. UI posts `feature_proposal` to `/evaluate`.
2. Server loads product docs once per request.
3. Server starts one thread per evaluator.
4. Each evaluator calls OpenAI with its own rubric-focused prompt.
5. Endpoint returns:
   - `evaluations`: successful evaluator JSON objects
   - `errors`: failed evaluator entries (`agent`, `error_code`, `message`)
   - `meta`: `total`, `succeeded`, `failed`

## Safety and Reliability
- `OPENAI_API_KEY` loaded from env, never returned to clients.
- Per-evaluator timeout to avoid hanging requests.
- Response parser enforces required output keys.
- Upstream errors are sanitized before returning to UI.

## Non-Goals (This Phase)
- Orchestrator recommendation / overall score.
- Advanced retry queues or background jobs.
- Prompt optimization beyond baseline rubric prompts.
