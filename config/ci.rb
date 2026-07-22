# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Database: Phase 2 migration round-trip", "bin/verify-phase-2-migrations"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Setup: Test database", "env RAILS_ENV=test DATABASE_URL=$TEST_DATABASE_URL bin/rails db:prepare"
  step "Boot: Zeitwerk eager load", "env RAILS_ENV=test DATABASE_URL=$TEST_DATABASE_URL bin/rails zeitwerk:check"
  step "Tests: RSpec", "env CI=true RAILS_ENV=test DATABASE_URL=$TEST_DATABASE_URL bundle exec rspec"
  step "Tests: System", "env CI=true RAILS_ENV=test DATABASE_URL=$TEST_DATABASE_URL bundle exec rspec spec/system"
  step "Tests: Seeds", "env RAILS_ENV=test DATABASE_URL=$TEST_DATABASE_URL bin/rails db:seed:replant"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
