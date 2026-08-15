# Phase 11 Review Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close all eight Phase 11 review findings while preserving the HTTP-first financial contract.

**Architecture:** Route constraints reject noncanonical UUID v7 values before controller queries. Controllers retain submitted form state while views render navigation, readonly archived screens and email-based financial context using existing read models. No service, migration, schema or ledger formula changes.

**Tech Stack:** Rails 8.1, Ruby 4, Pundit, Devise, RSpec request/system specs, Capybara Rack::Test, ViewComponent and Tailwind.

## Global Constraints

- Monetary values remain `Integer` cents; never use `float`.
- Successful mutations return 303; all actions retain backend authorization.
- Invalid route IDs return 404 before sensitive SQL; out-of-scope records return 404.
- Archived groups are readable and only restoration remains mutable.
- 422/409 preserve submitted values; 409 refreshes only financial state/version.
- Suggestions stay out of history; all user-facing financial labels use e-mail.
- Do not add Turbo, Action Cable, graph, schema, permissions or financial behavior.
- Do not change GitHub Project status until the new gate, per user direction.

---

### Task 1: Constrain every HTML route identifier

**Files:** Modify `lib/canonical_uuid_v7_route_constraint.rb`, `config/routes.rb`, and all five request specs.

**Interfaces:** `CanonicalUuidV7RouteConstraint.new(*parameter_names)` validates `request.path_parameters` for canonical lower-case UUID v7 values.

- [ ] **Step 1: Write failing request specs**

```ruby
it "returns 404 before querying groups for a malformed nested group_id" do
  queries = capture_group_queries
  post "/groups/not-a-uuid/expenses", params: valid_expense_params
  expect(response).to have_http_status(:not_found)
  expect(queries).to be_empty
end
```

Add cases for group update/archive/restore and nested expense, payment, membership and invitation IDs.

- [ ] **Step 2: Run Red**

Run `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/requests/groups_spec.rb spec/requests/expenses_spec.rb spec/requests/payments_spec.rb spec/requests/memberships_spec.rb spec/requests/group_invitations_spec.rb`.

Expected: a malformed nested value reaches SQL or misses the required 404 boundary.

- [ ] **Step 3: Implement the constraint**

```ruby
def initialize(*parameter_names)
  @parameter_names = parameter_names.map(&:to_s).freeze
end

def matches?(request)
  @parameter_names.all? { |name| UUID_V7_PATTERN.match?(request.path_parameters.fetch(name, "")) }
end
```

Apply it to every dynamic group/member route using `:group_id` and `:id` as appropriate.

- [ ] **Step 4: Run Green and related specs**

Run the Step 2 command. Expected: all new cases pass with no sensitive-table query.

- [ ] **Step 5: Commit**

Run `git add lib/canonical_uuid_v7_route_constraint.rb config/routes.rb spec/requests && git commit -m "fix: constrain all HTML UUID routes"`.

### Task 2: Preserve expense and payment form state

**Files:** Modify `app/controllers/expenses_controller.rb`, `app/controllers/payments_controller.rb`, `app/views/groups/show.html.erb`, `app/views/expenses/show.html.erb`, `spec/requests/expenses_spec.rb`, `spec/requests/payments_spec.rb`.

**Interfaces:** `@expense_form`, `@correction_form`, `@payment_form`, and `@current_financial_state_version` feed the matching rendered form.

- [ ] **Step 1: Write failing request specs**

```ruby
it "keeps every exact split field after 422" do
  post expense_path, params: exact_params(amount_text: "20,00", shares: invalid_exact_shares)
  expect(response.body).to include("20,00", "10,00", payer.email)
end

it "keeps report amount and idempotency key while refreshing stale version" do
  key = SecureRandom.uuid
  post payments_path, params: stale_report_params(amount_text: "5,00", idempotency_key: key)
  expect(response.body).to include("5,00", key, group.reload.financial_state_version.to_s)
end
```

- [ ] **Step 2: Run Red**

Run `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/requests/expenses_spec.rb spec/requests/payments_spec.rb`.

Expected: exact fields and original payment key/amount disappear.

- [ ] **Step 3: Implement minimal view state**

Use `@expense_form` for date, payer, participant checkboxes and shares in both split forms. In `render_payment_conflict`, retain permitted `payment_params`; render matching transfer values and key while setting hidden version to `@group.financial_state_version`.

- [ ] **Step 4: Run Green and related specs**

Run the Step 2 command. Expected: 422/409 preserve state and persist no failed command.

- [ ] **Step 5: Commit**

Run `git add app/controllers app/views spec/requests/expenses_spec.rb spec/requests/payments_spec.rb && git commit -m "fix: preserve HTML financial form state on errors"`.

### Task 3: Make archived HTML read-only with actionable errors

**Files:** Modify `app/controllers/application_controller.rb`, `app/views/groups/show.html.erb`, `app/views/expenses/show.html.erb`, `app/views/payments/show.html.erb`, plus group/expense/membership request specs.

**Interfaces:** `Group#archived_at?` gates all view mutations; domain errors render `AlertComponent` with the existing mapped status and specific safe message.

- [ ] **Step 1: Write failing specs**

```ruby
it "renders an archived group with restore only" do
  group.update!(archived_at: Time.current)
  get group_path(group)
  expect(response.body).to include("Restaurar grupo")
  expect(response.body).not_to include("Registrar despesa", "Salvar nome", "Enviar convite")
end
```

Add archived expense-detail and blocked membership assertions, including `saldo oficial diferente de zero` in the 422 body.

- [ ] **Step 2: Run Red**

Run `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/requests/groups_spec.rb spec/requests/expenses_spec.rb spec/requests/memberships_spec.rb`.

Expected: mutating controls remain visible or the generic alert hides the reason.

- [ ] **Step 3: Implement guards and message rendering**

Wrap every mutation form/button except owner restore in `unless group.archived_at?`. Render the mapped domain error through `AlertComponent` without rescuing unknown exceptions.

- [ ] **Step 4: Run Green and related specs**

Run the Step 2 command. Expected: archived pages are operationally read-only and blocked actions state why.

- [ ] **Step 5: Commit**

Run `git add app/controllers app/views spec/requests && git commit -m "fix: render archived groups as read-only"`.

### Task 4: Scope invitation expiry and restore navigation

**Files:** Modify invitation/group controllers, layout, home/groups views, group-invitation/group request specs, and system journey.

**Interfaces:** Invitation expiry consumes `policy_scope(GroupInvitation)` before `GroupInvitationExpirer`; authenticated navigation exposes `groups_path` and `invitations_path`.

- [ ] **Step 1: Write failing specs**

```ruby
it "does not expire another user's invitation when listing the inbox" do
  get invitations_path
  expect(other_users_expired_invitation.reload).to be_pending
end

it "links authenticated users to groups and invitations" do
  get root_path
  expect(response.body).to include(groups_path, invitations_path)
end
```

Also assert that an owner does not see a pending invitation at exact `expires_at` and history entries link to their details.

- [ ] **Step 2: Run Red**

Run `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/requests/group_invitations_spec.rb spec/requests/groups_spec.rb spec/system/group_settlement_spec.rb`.

Expected: cross-user mutation, absent navigation, stale owner pending invitation or absent detail links.

- [ ] **Step 3: Implement scope-first expiry and navigation**

Materialize the policy scope before expiring only overdue visible invitations. Exclude overdue pending invitations from owner display. Add auth nav, inbox before group list, and expense/payment history links.

- [ ] **Step 4: Run Green and related specs**

Run the Step 2 command. Expected: only visible invitations mutate and all navigation links appear.

- [ ] **Step 5: Commit**

Run `git add app/controllers app/views spec/requests spec/system/group_settlement_spec.rb && git commit -m "fix: scope invitations and complete HTML navigation"`.

### Task 5: Complete explainable dashboard/history and membership operations

**Files:** Modify dashboard/history queries, group/expense views, query specs, expense/membership request specs.

**Interfaces:** Dashboard snapshot adds an immutable `user_id => email` lookup. History entry exposes status/replacement context derived only from the record. Existing `MembershipOrderer` route accepts the owner form.

- [ ] **Step 1: Write failing specs**

```ruby
it "renders balances and plan with emails rather than UUIDs" do
  get group_path(group)
  expect(response.body).to include(owner.email, debtor.email)
  expect(response.body).not_to include("#{owner.id} paga")
end

it "renders the owner membership order form" do
  get group_path(group)
  expect(response.body).to include("Salvar ordem dos membros")
end
```

Add query/history examples for voided/replacement facts, a contextual third-party expense line, and UI coverage for equal and exact correction forms.

- [ ] **Step 2: Run Red**

Run `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/queries/group_dashboard_query_spec.rb spec/queries/group_history_query_spec.rb spec/requests/memberships_spec.rb spec/requests/expenses_spec.rb`.

Expected: UUID labels, no membership form, no correction context or exact correction path.

- [ ] **Step 3: Implement presentation metadata and forms**

Build the email map from all group memberships without persistence; render email labels, correction/void status and links. Add owner order controls posting all IDs in selected text order. Render equal/exact correction choice using the existing `ExpenseCorrectionForm` interface and preserve its values.

- [ ] **Step 4: Run Green and related specs**

Run the Step 2 command. Expected: dashboard/history are explainable and every implemented membership/correction operation is reachable by HTML.

- [ ] **Step 5: Commit**

Run `git add app/queries app/views spec/queries spec/requests && git commit -m "fix: complete explainable HTML group operations"`.

### Task 6: Add normative CSRF, scope and parameter coverage; run gate

**Files:** Modify the five request specs, add `spec/policies/group_invitation_policy_spec.rb`, update `PROJECT.md` and `README.md` after evidence.

**Interfaces:** Rails forgery protection is enabled temporarily in the example; controllers map missing form envelopes to 422 without hiding unexpected errors.

- [ ] **Step 1: Write failing tests**

```ruby
it "rejects a state-changing request without CSRF token when protection is enabled" do
  with_forgery_protection { post groups_path, params: { group: { name: "Casa" } } }
  expect(response).to have_http_status(:unprocessable_entity)
end
```

Add cross-group tampering, missing expense envelope and invitation-policy examples.

- [ ] **Step 2: Run Red**

Run `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/requests spec/policies`.

Expected: uncovered contract tests fail before the missing behavior is completed.

- [ ] **Step 3: Implement only missing HTTP behavior**

Use the existing Rails forgery mechanism. Ensure missing form envelopes return 422 through parameter/form handling; retain unexpected exceptions. Update local status docs only after the full gate and do not change remote Project state.

- [ ] **Step 4: Run all verification**

Run:

```bash
docker compose run --rm web bin/rails tailwindcss:build
docker compose run --rm web bin/verify-financial-schema-migrations
docker compose run --rm web bin/rubocop
docker compose run --rm web bin/ci
bin/verify-production-image
git diff --check
```

Expected: every command exits 0 and RSpec executes the new request, policy and system examples.

- [ ] **Step 5: Commit**

Run `git add spec PROJECT.md README.md && git commit -m "test: harden phase 11 HTTP contracts"`.

## Self-review

- Tasks 1–6 cover every review finding: route boundary, form preservation, archived readonly, scoped expiry, navigation/history, e-mail presentation, membership ordering, correction reachability, specific errors and test gaps.
- The plan has no schema/domain/remote-project mutation and contains no deferred implementation placeholders.
