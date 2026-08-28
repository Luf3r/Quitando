# Extensão demo da Fase 13 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reabrir a Fase 13 com histórico auditável de convites e um cenário demo público, íntegro e reproduzível.

**Architecture:** A primeira entrega acrescenta consultas e apresentação de fatos de convite sem alterar suas transições. A segunda adiciona um instalador/resetter transacional, guardado por configuração e lock PostgreSQL, que usa os comandos existentes do domínio para materializar um ambiente demo descartável.

**Tech Stack:** Rails 8, PostgreSQL 18, RSpec, Devise, Pundit, Solid Queue, Tailwind e Docker Compose.

**Spec:** `docs/superpowers/specs/2026-08-28-demo-scenario-design.md`

## Global Constraints

- A extensão é Fase 13.15–13.16; Fase 14 não recebe cenário demo, UI de convite ou comportamento visual pendente.
- Use somente centavos inteiros, comandos financeiros existentes e broadcasts pós-commit.
- Cada comportamento novo exige Red, Green e Refactor; erro e caminho principal são especificados separadamente.
- `QUITANDO_DEMO_MODE=true`, `QUITANDO_DEMO_DATABASE_NAME` exato, `QUITANDO_DEMO_PASSWORD` e `CONFIRM_DEMO_RESET=quitando-demo-only` têm significado literal.
- Reset usa advisory lock compartilhado, `lock_timeout=10s`, `statement_timeout=60s`, transaction única e nunca toca tabelas de metadados Rails.
- Nunca registrar descrição financeira, token ou payload financeiro em evento operacional.

---

### Task 1: Reabrir Fase 13 e formalizar os contratos

**Files:**
- Modify: `docs/02-projeto-quitando.md`, `docs/03-quitando-domain-architecture.md`, `docs/04-quitando-ux-ui.md`, `docs/05-quitando-roadmap-implementacao.md`, `docs/07-quitando-decisoes-consolidadas.md`, `PROJECT.md`, `README.md`
- Create: `docs/adr/0019-demo-production-is-discardable.md`

**Produces:** Fase 13 reaberta com 13.15 (histórico) e 13.16 (demo); Fase 14 reduzida a hardening/deploy.

- [ ] Registrar no GitHub Project as subissues dependentes e mover somente 13.15 para `In progress`.
- [ ] Atualizar fontes normativas com a fronteira demo-only, o reset de seis horas, o histórico e o novo gate.
- [ ] Criar ADR append-only para banco/deploy demo separado e reset integral.
- [ ] Confirmar que nenhuma regra financeira, estado financeiro ou permissão financeira foi alterada.

### Task 2: Histórico auditável de convites

**Files:**
- Create: `app/queries/group_invitation_history_query.rb`, `spec/queries/group_invitation_history_query_spec.rb`
- Modify: `app/policies/group_invitation_policy.rb`, `app/controllers/invitations_controller.rb`, `app/controllers/groups_controller.rb`, `app/views/invitations/index.html.erb`, `app/views/groups/settings.html.erb`, `config/routes.rb`
- Test: `spec/requests/invitations_spec.rb`, `spec/requests/group_history_and_settings_spec.rb`

**Consumes:** Convites terminais existentes e `GroupInvitationExpirer` idempotente.

**Produces:** `GroupInvitationHistoryQuery::Page`, com 25 itens, ordem terminal timestamp/ID e paginação validada.

- [ ] Escrever spec Red para política recebida incluir convite terminal e a página recebida separar pendentes de encerrados.
- [ ] Rodar a spec e confirmar falha por o escopo ainda filtrar `pending`.
- [ ] Implementar o menor query/controller/view que materializa os dois históricos sem ações terminais.
- [ ] Rodar specs focadas, request specs de `422` e autorização do histórico enviado.
- [ ] Refatorar somente depois de Green e registrar evidência.

### Task 3: Contas demo e persistência de cenário

**Files:**
- Create: migration para `users.demo_account` e `demo_scenarios`; `app/models/demo_scenario.rb`; `app/services/demo_scenario/config.rb`
- Modify: `app/models/user.rb`, `db/structure.sql`, `spec/database/financial_schema_contract_spec.rb`
- Test: `spec/models/user_spec.rb`, `spec/services/demo_scenario/config_spec.rb`, `spec/database/financial_schema_contract_spec.rb`

**Produces:** configuração validada e persistência mínima, sem instalar dados ainda.

- [ ] Escrever Red para flag imutável pelo fluxo demo e rejeição de configuração/banco não autorizados.
- [ ] Rodar a Red contra PostgreSQL real.
- [ ] Criar migration segura e configuração sem valores padrão silenciosos.
- [ ] Executar spec focada, contrato de banco e conjunto relacionado.

### Task 4: Instalação canônica por comandos de domínio

**Files:**
- Create: `app/services/demo_scenario/installer.rb`, `spec/services/demo_scenario/installer_spec.rb`
- Modify: `db/seeds.rb`, `bin/rails` task definitions quando necessário

**Consumes:** `DemoScenario::Config` e serviços de grupos, despesas, pagamentos, correções e convites.

**Produces:** `DemoScenario::Installer.call` idempotente com quatro contas e todos os estados canônicos.

- [ ] Escrever Red para instalação produzir contas públicas e os grupos/estados especificados.
- [ ] Rodar Red e verificar ausência de dados, não erro de boot.
- [ ] Construir o cenário apenas por comandos reais e validar suas invariantes no final da transação.
- [ ] Provar segunda instalação sem duplicação e ledger oficial/projetado zero-sum.

### Task 5: Reset transacional, job e entradas operacionais

**Files:**
- Create: `app/services/demo_scenario/resetter.rb`, `app/jobs/demo_scenario_reset_job.rb`, `lib/tasks/demo.rake`, `bin/verify-demo-scenario`
- Modify: `config/recurring.yml`, entrypoints Docker/produção, `bin/ci`
- Test: `spec/services/demo_scenario/resetter_spec.rb`, `spec/jobs/demo_scenario_reset_job_spec.rb`, `spec/infrastructure/demo_scenario_verifier_spec.rb`

**Produces:** reset manual e periódico guardado, concorrente e totalmente atômico.

- [ ] Escrever Red para reset recusar banco incorreto e confirmação manual ausente antes de `TRUNCATE`.
- [ ] Rodar Red com conexão de teste real e observar a fronteira de consulta/efeito.
- [ ] Implementar transaction, advisory lock, timeouts, retry e eventos operacionais sem dados financeiros.
- [ ] Provar rollback integral, contenção, snapshot canônico e cleanup de banco temporário pelo verificador real.

### Task 6: Credenciais protegidas e apresentação demo

**Files:**
- Modify: controllers/views Devise, `AccountsController`, layout e landing/login; locales e CSS
- Test: request/system specs de autenticação, conta e banner

**Produces:** credenciais demo visíveis para entrar, mas imutáveis e irrecuperáveis no backend; banner acessível com próximo reset.

- [ ] Escrever Red para conta demo não conseguir alterar e-mail/senha e não receber fluxo de recuperação revelador.
- [ ] Implementar guardas de backend antes de desabilitar a UI.
- [ ] Exibir emails, senha configurada e política de reset somente em demo mode.
- [ ] Verificar HTTP sem JavaScript, foco e mensagens visíveis.

### Task 7: Gate integrado e reconciliação

**Files:**
- Modify: `PROJECT.md`, `README.md`, `docs/05-quitando-roadmap-implementacao.md`, issue/subissues/Project
- Test: todos os comandos do gate definido na spec

- [ ] Rodar `bin/verify-demo-scenario`, RSpec, Tailwind, `bin/ci`, imagem de produção e `git diff --check` sobre o diff final.
- [ ] Provar boot da imagem demo com cenário instalado antes do primeiro HTTP 200.
- [ ] Atualizar a fase e o Project apenas com evidência fresca e registrar Red/Green nas issues.
