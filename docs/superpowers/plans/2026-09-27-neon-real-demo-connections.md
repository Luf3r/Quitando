# Neon Real and Demo Connections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Fly release reject wrong Neon connection topology before migrations and document the eight connection URLs for each of the real and demo projects.

**Architecture:** Keep the two Fly apps and four databases per project already defined in the codebase. A Ruby preflight checks four direct/pooled URL pairs, opens all eight endpoints read-only, and verifies PostgreSQL identity/version before `bin/fly-release` runs `db:prepare`. The README explains provisioning and secret mapping without values.

**Tech Stack:** Rails 8.1, Ruby 4.0, pg gem, PostgreSQL 18, RSpec, Fly.io, Neon.

**Spec:** `docs/superpowers/specs/2026-09-27-neon-real-demo-connections-design.md`

## Global Constraints

- Two separate Neon projects and Fly apps; primary database names `Quitando` and `Demo`.
- Four databases per project: primary, cache, queue, cable.
- Runtime uses pooled URLs and release migrations use direct URLs.
- Demo reset requires exact `QUITANDO_DEMO_DATABASE_NAME=Demo`.
- No URL or credential in tracked files, test output, or error messages.
- A failed preflight is an error. No fallback is authorized.

## Review Focus

- A URL with a `dbname` query parameter could override its path: reject it before connecting.
- A direct URL paired with the wrong pooler database could send runtime traffic elsewhere: compare database and username.
- An auxiliary URL from the other project could cross the isolation boundary: compare all direct endpoints and all pooled endpoints.
- A non-Neon or malformed URL could pass string checks: require valid PostgreSQL URI fields and the direct/pooler host relationship.
- A connection or version failure could migrate the other databases first: complete every read-only check before calling `db:prepare`.

---

### Task 1: Validate Neon topology and connectivity before migrations

**Files:**
- Create: `lib/neon_deployment/preflight.rb`
- Create: `bin/verify-neon-connections`
- Modify: `bin/fly-release`
- Modify: `config/database.yml`
- Modify: `fly.main.toml`, `fly.demo.toml`
- Create: `spec/scripts/neon_connections_spec.rb`
- Create: `spec/scripts/production_database_config_spec.rb`
- Modify: `spec/scripts/fly_release_spec.rb`

**Interfaces:**
- Consumes: eight URL environment variables and `QUITANDO_DEMO_MODE`, `QUITANDO_DEMO_DATABASE_NAME`, `QUITANDO_MAIN_DATABASE_NAME`.
- Produces: `NeonDeployment::Preflight#call!`, raising `ConfigurationError` or `ConnectionError` without URL contents; `bin/verify-neon-connections` exits nonzero on failure.

- [x] Add RSpec examples for valid real/demo mappings, missing and malformed URLs, `dbname` override, crossed host, mismatched pair, repeated database name, wrong mode/name, inaccessible database, and PostgreSQL version below 18. Assertions observe that no `db:prepare` or seed runs after preflight failure.
- [x] Run the focused specs and record the expected Red for missing `NeonDeployment::Preflight` and missing release preflight call.
- [x] Implement URI parsing and role comparison in `lib/neon_deployment/preflight.rb`. Check all eight connections with `pg` using bounded connection and statement timeouts, `current_database()` and `server_version_num`; close every connection. Report only variable or role names on error.
- [x] Add executable `bin/verify-neon-connections` and call it from `bin/fly-release` before exporting direct URLs and before `db:prepare`.
- [x] Add a production configuration spec that resolves Rails database names, hosts, and users from fake Neon runtime URLs for both app modes.
- [x] Run focused specs (20 examples, 0 failures), related script specs, and current `bin/ci` (699 RSpec + 43 system examples, passed on final run). The initial full run had one transient theme preference failure; the isolated example and repeated system suite passed.
- [x] Verify the production image; `git diff --check` clean. No remote migration or deployment was run.
- [ ] Commit Task 1 after final secret scan and review.

### Task 2: Provisioning runbook and state reconciliation

**Files:**
- Modify: `README.md`
- Modify: `PROJECT.md`

**Interfaces:**
- Consumes: Task 1's variable names and exact preflight behavior.
- Produces: instructions for creating six auxiliary databases, mapping four pooled and four direct URLs per app, checking PostgreSQL 18, setting distinct app secrets, and invoking release and smoke checks.

- [x] Write the operational steps with placeholder names only; distinguish local development from the two production apps and note that pooled/direct URLs target the same database.
- [x] State the verified progress and remaining Fly/Neon provisioning work without marking the Fase 14 gate complete.
- [x] Run `git diff --check`, focused and related specs, `bin/ci`, and production image verification. Fly smoke remains unrun because no deployment was requested and the Phase 13 human gate remains pending.
- [ ] Commit Task 2 after final secret scan and review the full branch for unintended scope changes.
