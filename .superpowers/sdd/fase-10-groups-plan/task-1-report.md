# Task 1 report — Contrato, ADR e schema da Fase 10

## Status

Concluída. Impacto documental: **comportamento**.

## Contrato executado

- **Fase/gate:** Fase 10; o schema agora suporta o ciclo de convite sem conceder membership ou acesso financeiro antes de uma futura aceitação transacional.
- **Fontes consultadas:** `PROJECT.md`, `AGENTS.md`, `docs/00-index.md`, roadmap §13, domínio §§5.1–5.2/6.1–6.3/7.2–7.3, produto, UX, decisões consolidadas, ADR-0010 e ADR-0014, e issue #80.
- **Principal:** somente BRL é persistível no MVP; `group_invitations` guarda convites internos auditáveis; posição de membership permanece única e pode ser reordenada atomicamente.
- **Invariantes preservadas:** `memberships(group_id, user_id)` continua única; `financial_state_version` não foi alterada; convite `pending` não cria membership nem participa de qualquer caminho financeiro; PKs usam `uuidv7()`; locks de migration restauram `lock_timeout`.
- **Entradas/falhas:** `currency_code` diferente de BRL, nome vazio ou só whitespace, estado de convite inválido, auditoria parcial/incompatível, FKs ausentes e segundo convite `pending` são recusados pelo PostgreSQL. Dados legados incompatíveis fazem `ADD CHECK` falhar; a migration não os transforma.
- **Fora do escopo:** commands de convite, autorização, HTTP, controllers, UI, Turbo/Action Cable, jobs, e-mail, links públicos e mudança de versão financeira.
- **Contratos afetados:** domínio, PostgreSQL, models, factories, verificador de migrations e documentação. Sem fallback autorizado.

## Implementação

- Migration `20260808210000_add_group_invitations_and_group_contracts` cria `group_invitations` com UUID v7, FKs, expiração obrigatória, enum protegido e auditoria exclusiva por estado (`accepted_at`, `declined_at`, `revoked_at`, `expired_at`).
- Índice parcial único garante um só `pending` por `(group_id, invited_user_id)`; convites terminais permanecem no histórico.
- Checks de grupo exigem `currency_code = 'BRL'` e nome não vazio.
- A unicidade de `memberships(group_id, position)` passou a ser constraint `DEFERRABLE INITIALLY IMMEDIATE`.
- `GroupInvitation`, associações de `Group`/`User`, factory e schema dump foram adicionados.
- ADR-0015 complementa ADR-0010; produto, domínio, UX, decisões consolidadas e índice foram sincronizados.

## Evidência TDD

### Red

1. `docker compose run --rm --no-deps web bundle exec rspec spec/database/financial_schema_contract_spec.rb:130`
   - 19 exemplos, 1 falha esperada: `group_invitations` não existia.
2. `docker compose run --rm --no-deps web bundle exec rspec spec/models/group_invitation_spec.rb`
   - 1 exemplo, 1 falha esperada: constante `GroupInvitation` ausente.
3. `docker compose run --rm --no-deps web bundle exec rspec spec/models/group_spec.rb:4`
   - 1 exemplo, 1 falha esperada: associação `group_invitations` ausente.
4. `docker compose run --rm --no-deps web bundle exec rspec spec/models/group_invitation_spec.rb:33`
   - 1 exemplo, 1 falha esperada: factory `group_invitation` ausente.
5. `docker compose run --rm --no-deps web bundle exec rspec spec/infrastructure/financial_schema_migration_verifier_spec.rb`
   - 12 exemplos, 1 falha esperada: o verificador não exercitava o round-trip/restore de timeout da Fase 10.

### Green e refactor

- Após cada fatia, as specs focadas passaram; o conjunto estrutural PostgreSQL passou com **23 exemplos, 0 falhas**.
- A factory recebeu traits de estados terminais porque `FactoryBot.lint(traits: true)` revelou a exigência real dos timestamps de auditoria; após a correção, lint de factories e specs de model passaram com **5 exemplos, 0 falhas**.
- `docker compose run --rm --no-deps web bin/verify-financial-schema-migrations` passou, incluindo rollback/up real da Fase 10 e restauração de `lock_timeout`.
- `docker compose run --rm --no-deps web bin/normalize-structure-sql` e RuboCop focal passaram: **9 arquivos, 0 offenses**.
- `docker compose run --rm --no-deps web bin/ci` terminou com exit 0 sobre o diff atual.

## Arquivos alterados

- Schema/models/factory: `db/migrate/20260808210000_add_group_invitations_and_group_contracts.rb`, `db/structure.sql`, `app/models/group_invitation.rb`, `app/models/group.rb`, `app/models/user.rb`, `spec/factories/group_invitations.rb`.
- Specs/verificador: `spec/database/financial_schema_contract_spec.rb`, `spec/models/group_invitation_spec.rb`, `spec/models/group_spec.rb`, `spec/infrastructure/financial_schema_migration_verifier_spec.rb`, `bin/verify-financial-schema-migrations`.
- Documentação: ADR-0015, índice, produto, domínio, UX e decisões consolidadas.

## Concerns

- A aceitação, recusa, revogação e expiração ainda não possuem commands nem autorização; isso é deliberadamente reservado às próximas tarefas da Fase 10.
- Um rollback da migration descarta convites, como esperado para rollback de schema; não há comando de produção que o execute automaticamente.
