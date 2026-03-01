# Project Tags + Test Projects Design

Date: 2026-03-01

## Goal
Make it easy to test Gareth with multiple product definitions by selecting a test project in the UI. Each project corresponds to a folder in `projects/` containing only `.md` product definition files. The selected project is sent alongside the feature proposal to the OpenAI API.

## Context
Current evaluation reads fixed files from `product-description/`. This makes testing multiple “products” cumbersome. We want a simple way to switch between sets of product definitions.

## Approach Options (with trade-offs)
1. Server-rendered tags (recommended)
   - Server scans `projects/` at app start, injects list into `index.erb`, JS submits selected project on evaluate.
   - Pros: simplest, no extra endpoint, deterministic at app start.
   - Cons: must reload page to see new folders.
2. Client fetch on load
   - Add `/projects` endpoint and fetch list on page load.
   - Pros: separation of concerns, reusable list endpoint.
   - Cons: extra endpoint and JS logic.
3. Config-based list
   - Keep `projects.yml` with explicit list of projects.
   - Pros: explicit control, no filesystem scan.
   - Cons: manual upkeep, can drift from actual folders.

Selected: Option 1.

## Architecture
- On app start, Sinatra scans `/home/nelis/Dev/gareth/projects` for subfolders.
- Each subfolder name becomes a selectable tag in the UI.
- Selected tag value is posted to `/evaluate` as `project=<name>`.
- Server reads only `.md` files in `/home/nelis/Dev/gareth/projects/<project>` to build the `docs` payload passed to evaluators.
- No fallback to `product-description`.

## UI + Data Flow
- A horizontal tag bar at the top of the page shows all project names as colorized buttons.
- Only one tag can be active at a time.
- Default selection is the first tag in alphabetical order.
- JS stores the selected project name and includes it in the evaluate request.

## Error Handling
- If `projects/` is missing or empty, render a warning in the tag area and disable Evaluate.
- If `project` param points to a missing folder, return 400 with a clear error message.
- If no `.md` files exist in the selected folder, return 400 indicating no `.md` files found.

## Test Examples
- Add a small set of example project folders under `projects/` with minimal `.md` files that map to evaluator keys: `strategy`, `vision`, `jtbd`, `user_flows`, `product_charter`, `feedback`.
- Provide a lightweight manual test checklist if automated tests are not present.

## Testing Plan
- Manual: start server, verify tags render, select different tag, evaluate, confirm `.md` content is used and errors are surfaced.
