# Phase 11 Review Follow-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the three remaining Phase 11 review findings with observable HTTP contracts.

**Architecture:** Preserve stale payment input in a dedicated conflict section instead of binding it to a new transfer. Render correction links from each direct relationship. Expand request boundary specs while retaining route-level constraints.

**Tech Stack:** Rails 8, ERB, RSpec request specs, PostgreSQL-backed Rails models.

## Global Constraints

- HTTP is primary; no JavaScript dependency.
- Invalid route IDs return 404 before sensitive queries.
- 409 keeps submitted state visible but never silently targets a new suggestion.
- Expense history remains append-only and correction chains are navigable.

---

### Task 1: Preserve payment conflict state separately

**Files:**
- Modify: `app/controllers/payments_controller.rb`, `app/views/groups/show.html.erb`
- Test: `spec/requests/payments_spec.rb`

- [ ] Write a failing request spec where a stale report no longer has a matching current transfer and assert the 409 still displays submitted source, destination, amount and idempotency key.
- [ ] Run `docker compose run --rm web bundle exec rspec spec/requests/payments_spec.rb` and verify the new example fails.
- [ ] Store the submitted payment attributes in `@payment_conflict` and render a read-only conflict section; leave current-plan forms populated only from their own transfers.
- [ ] Re-run the request spec and verify it passes.

### Task 2: Make correction chains navigable

**Files:**
- Modify: `app/views/expenses/show.html.erb`, `app/views/groups/show.html.erb`
- Test: `spec/requests/expenses_spec.rb`, `spec/queries/group_history_query_spec.rb`

- [ ] Write a failing request spec for original → replacement → replacement asserting every direct relation appears as a detail link and both replacement/voided facts appear.
- [ ] Run `docker compose run --rm web bundle exec rspec spec/requests/expenses_spec.rb spec/queries/group_history_query_spec.rb` and verify failure.
- [ ] Render all direct `replaces_expense` and `replacement_expenses` relations as links and render both cycle labels when applicable.
- [ ] Re-run the focused specs and verify they pass.

### Task 3: Cover nested route identifier boundaries

**Files:**
- Test: `spec/requests/expenses_spec.rb`, `spec/requests/payments_spec.rb`, `spec/requests/group_invitations_spec.rb`

- [ ] Add failing request specs for malformed `group_id` and mutating `correct`, `confirm`, and `revoke` paths, subscribing to SQL and asserting no financial-table queries.
- [ ] Run the focused request specs and verify the new checks pass using the existing route constraints.
- [ ] Run `docker compose run --rm web bundle exec rspec`, `docker compose run --rm web bundle exec rubocop`, and `git diff --check`.
