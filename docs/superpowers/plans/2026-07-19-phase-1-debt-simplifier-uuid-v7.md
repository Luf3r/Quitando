# Fase 1: DebtSimplifier com UUID v7 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Concluir o gate da Fase 1 com um `DebtSimplifier` Ruby puro, determinístico e coberto por exemplos, propriedades e isolamento, adotando UUID v7 como identidade persistente do projeto.

**Architecture:** PostgreSQL 18 gera todas as chaves primárias UUID com `uuidv7()` e Rails trata os identificadores como strings UUID canônicas. O `DebtSimplifier` permanece independente de banco e framework; valida um `Hash<String, Integer>` e usa duas filas binárias privadas para produzir transferências em `O(m log m)`, com desempate lexicográfico crescente.

**Tech Stack:** Ruby 4.0.6, Rails 8.1.3, PostgreSQL 18, RSpec 8, FactoryBot, `pbt` 0.7.0 e Docker Compose.

## Global Constraints

- Dinheiro usa exclusivamente `Integer` em centavos; `float` é proibido.
- UUIDs aceitos pelo serviço são UUID v7 canônicos, minúsculos e com variante RFC válida.
- Toda PK persistente é `uuid` com default explícito `uuidv7()`; toda FK futura será `uuid`.
- O serviço não carrega Rails, ActiveRecord ou banco.
- Sugestões são derivadas e não são persistidas como pagamentos.
- Nenhum fallback é autorizado; entradas inválidas falham com erros tipados.
- A entrada não pode ser modificada.
- Property tests executam 250 casos sem workers, com seed reportável e shrinking.
- Execução ocorre na worktree `.worktrees/phase-1-debt-simplifier-uuid-v7`, branch `feat/phase-1-debt-simplifier-uuid-v7`.

---

## Contrato da tarefa

**Fase e gate:** Fase 1 — `DebtSimplifier` em Ruby puro. O gate exige todos os invariantes sem carregar Rails ou ActiveRecord. UUID v7 é pré-requisito arquitetural para alinhar a API pura às identidades persistentes da Fase 2.

**Fontes normativas consultadas:** `PROJECT.md`; `AGENTS.md`; `docs/00-index.md`; seções 4 e 5 do roadmap; seções 5.5, 6, 8.3 e 13.2 de domínio; seções 4.1, 7 e 13.2 do produto; decisões consolidadas; ADR-0003; issues `#6`, `#7`, `#20–#28`; GitHub Project Quitando.

**Comportamento observável principal:**

- usuários persistidos recebem PK UUID v7 gerada pelo PostgreSQL 18;
- `DebtSimplifier.new(balances).call` recebe `Hash<String, Integer>`;
- retorna `Array<DebtSimplifier::Transfer>`;
- valida estrutura, UUID, saldo e soma zero, nessa ordem;
- casa maior dívida e maior crédito; empates usam UUID crescente;
- quita todos os saldos com transferências positivas, conservando valor, sem mutar entrada e usando no máximo `m - 1` transferências.

**Entradas válidas:** mapa vazio; UUIDs v7 canônicos para saldos inteiros; zeros; mapas com soma exatamente zero; magnitudes de um centavo e valores inteiros maiores.

**Entradas inválidas e falhas:** estrutura não `Hash` (`InvalidBalances`); ID não UUID v7 canônico (`InvalidUserId`); saldo não `Integer` (`InvalidBalance`); soma diferente de zero (`UnbalancedBalances`). Nenhuma falha é convertida em sucesso ou coleção vazia.

**Invariantes:** inteiros; soma zero; saída positiva; origem diferente do destino; quitação; conservação; determinismo; imutabilidade; `m - 1`; complexidade `O(m log m)`; ausência de Rails/ActiveRecord.

**Fora do escopo:** ledger, persistência de planos, solver exato, trace, HTTP, autorização, UI, real-time, deploy e demais entidades da Fase 2.

**Contratos afetados:** arquitetura, banco inicial, generators Rails, factory de `User`, API de domínio, serviço Ruby puro, specs e documentação. Sem contratos HTTP, autorização, UI, real-time ou deploy.

**Impacto documental:** UUID v7 = arquitetura; API UUID e desempate = comportamento; conclusão da Fase 1 = escopo/fase/gate; demais invariantes = implementação de contrato existente.

**Classificação comportamental:** todos os resultados solicitados são comportamento principal. Não há fallback autorizado. Erros tipados são recuperação explícita por entrada inválida, não sucesso. Entregas intermediárias das issues são implementação parcial até o gate final.

```text
Contrato solicitado: DebtSimplifier Ruby puro com identidades UUID v7 e invariantes completos
Comportamento principal: validar, simplificar e quitar saldos em O(m log m), com resultado determinístico e isolado do framework
Spec que prova o caminho principal: debt_simplifier_spec.rb, debt_simplifier_property_spec.rb e debt_simplifier_isolation_spec.rb
Fallbacks autorizados: nenhum
Specs dos fallbacks: não aplicável
Erros que permanecem visíveis: InvalidBalances, InvalidUserId, InvalidBalance e UnbalancedBalances
Evidência de que o fallback não é o caminho padrão: não existe código nem spec de fallback
```

---

### Task 1: Preparar worktree, baseline e quadro operacional

**Files:**

- Modify: `.gitignore`
- Create: `docs/superpowers/plans/2026-07-19-phase-1-debt-simplifier-uuid-v7.md`

**Interfaces:**

- Consumes: branch `develop` e Project #2.
- Produces: worktree isolada, baseline registrado e issue de pré-requisito UUID pronta para execução.

- [x] **Step 1: Verificar checkout, ignore e worktree**

Run:

```bash
git rev-parse --git-dir
git rev-parse --git-common-dir
git branch --show-current
git check-ignore -v .worktrees/test
```

Expected: checkout principal em `develop`; `.worktrees/` ignorada antes da criação.

- [x] **Step 2: Criar worktree**

Run:

```bash
git worktree add .worktrees/phase-1-debt-simplifier-uuid-v7 -b feat/phase-1-debt-simplifier-uuid-v7
```

Expected: branch e worktree criadas a partir de `develop`.

- [x] **Step 3: Executar baseline**

Run:

```bash
docker compose run --rm web bin/ci
```

Expected: 8 exemplos, 0 falhas; lint e auditorias aprovados.

- [x] **Step 4: Criar e iniciar pré-requisito UUID**

Criar issue com Phase `Fase 1`, Priority `P0`, Size `M`, Type `Infrastructure`, Milestone A, labels `database` e `infrastructure`, dependência `#5`; torná-la parent/subissue de `#6`, fazê-la bloquear `#20`, mover a nova issue para `In progress` e `#20` para `Blocked`.

---

### Task 2: Adotar UUID v7 no banco inicial

**Files:**

- Create: `docs/adr/0014-postgresql-uuid-v7-identifiers.md`
- Modify: `docs/00-index.md`
- Modify: `db/migrate/20260716180000_devise_create_users.rb`
- Modify: `config/application.rb`
- Modify: `spec/factories/users.rb`
- Modify: `spec/models/user_factory_spec.rb`
- Regenerate: `db/schema.rb`

**Interfaces:**

- Consumes: PostgreSQL 18 `uuidv7()`.
- Produces: `User.id: String` UUID v7 e configuração `primary_key_type: :uuid`.

- [x] **Step 1: Escrever Red do UUID persistido**

Adicionar a `spec/models/user_factory_spec.rb` expectativas diretas:

```ruby
expect(user.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
expect(User.connection.select_value("SELECT uuid_extract_version(#{User.connection.quote(user.id)}::uuid)")).to eq(7)
```

- [x] **Step 2: Confirmar Red**

Run:

```bash
docker compose run --rm web bundle exec rspec spec/models/user_factory_spec.rb
```

Expected: falha porque a PK atual é `bigint`, não UUID v7.

- [x] **Step 3: Implementar schema mínimo**

Alterar a migration para:

```ruby
create_table :users, id: :uuid, default: -> { "uuidv7()" } do |t|
```

Adicionar em `config/application.rb`:

```ruby
config.generators do |generators|
  generators.orm :active_record, primary_key_type: :uuid
end
```

Recriar bancos descartáveis e regenerar `db/schema.rb`.

- [x] **Step 4: Confirmar Green e inspecionar com psql**

Run:

```bash
docker compose run --rm web bundle exec rspec spec/models/user_factory_spec.rb
docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -P pager=off -U quitando -d quitando_test -c '\d+ users' -c "SELECT id, uuid_extract_version(id) FROM users LIMIT 1;"
```

Expected: PK `uuid`, default `uuidv7()`, versão `7`.

- [x] **Step 5: Documentar ADR-0014 e sincronizar fontes**

Registrar decisão, contexto, consequências, UUIDs como strings canônicas e desempate lexicográfico crescente. Atualizar índice, produto, domínio, roadmap e decisões consolidadas.

---

### Task 3: API, validações e mapa vazio — issues #20 e #21

**Files:**

- Create: `app/services/debt_simplifier.rb`
- Create: `spec/services/debt_simplifier_spec.rb`

**Interfaces:**

- Consumes: `Hash<String, Integer>`.
- Produces: `DebtSimplifier.new(balances).call`, `Transfer`, `InvalidBalances`, `InvalidUserId`, `InvalidBalance`, `UnbalancedBalances`.

- [x] **Step 1: Red da API e ordem de validação**

Criar specs para mapa vazio, `Transfer.members`, estrutura inválida, UUID inválido, saldo inválido e soma diferente de zero. Usar UUIDs v7 literais canônicos e verificar precedência de estrutura → ID → saldo → soma.

- [x] **Step 2: Executar Red**

Run:

```bash
docker compose run --rm web bundle exec rspec spec/services/debt_simplifier_spec.rb
```

Expected: `NameError` para `DebtSimplifier`.

- [x] **Step 3: Implementar Green mínimo**

Definir erros, `Transfer = Data.define(...)`, regex UUID v7/variante RFC, cópia do mapa e validações sequenciais; mapa vazio retorna `[]`.

- [x] **Step 4: Executar Green e refactor**

Run:

```bash
docker compose run --rm web bundle exec rspec spec/services/debt_simplifier_spec.rb
```

Expected: exemplos de API/erro aprovados.

---

### Task 4: Algoritmo guloso com filas binárias — issues #22–#25

**Files:**

- Modify: `app/services/debt_simplifier.rb`
- Modify: `spec/services/debt_simplifier_spec.rb`

**Interfaces:**

- Consumes: mapa validado e copiado.
- Produces: transferências tipadas ordenadas pelo pareamento guloso.

- [x] **Step 1: Red para um par**

Adicionar casos de `1` centavo e valor representativo. Esperar exatamente:

```ruby
DebtSimplifier::Transfer.new(
  from_user_id: debtor_id,
  to_user_id: creditor_id,
  amount_cents: 1
)
```

- [x] **Step 2: Confirmar Red e implementar pareamento mínimo**

Run antes e depois:

```bash
docker compose run --rm web bundle exec rspec spec/services/debt_simplifier_spec.rb
```

Expected Red: `[]` difere da transferência. Expected Green: par quitado.

- [x] **Step 3: Red/Green para zeros e entrada congelada**

Cobrir apenas zeros, zeros junto do par, mapa congelado e falha sem mutação. Implementar sem remover chaves da entrada.

- [x] **Step 4: Red/Green para múltiplos participantes**

Cobrir dois lados e liquidação parcial. Implementar duas filas binárias privadas cuja comparação seja magnitude decrescente e UUID crescente; reinserir somente resíduos.

- [x] **Step 5: Red/Green para empates e permutações**

Cobrir empate de devedores, credores e ambos; construir hashes em ordens diferentes e exigir a mesma sequência. A fila nunca usa ordem incidental do `Hash`.

- [x] **Step 6: Refactor com suíte focada**

Run:

```bash
docker compose run --rm web bundle exec rspec spec/services/debt_simplifier_spec.rb
```

Expected: todos os exemplos e erros aprovados.

---

### Task 5: Invariantes e properties — issues #26 e #27

**Files:**

- Modify: `Gemfile`
- Modify: `Gemfile.lock`
- Modify: `spec/services/debt_simplifier_spec.rb`
- Create: `spec/services/debt_simplifier_property_spec.rb`

**Interfaces:**

- Consumes: serviço real e geradores `pbt`.
- Produces: prova legível e gerativa de conservação, quitação, validade, determinismo, imutabilidade e `m - 1`.

- [x] **Step 1: Adicionar controles negativos mínimos em spec**

Criar helpers de asserção aplicáveis à saída real e a mutantes mínimos restritos à spec, como saída vazia para um mapa não quitado e transferência inválida isolada. Não duplicar o solver.

- [x] **Step 2: Executar controles negativos**

Run:

```bash
docker compose run --rm web bundle exec rspec spec/services/debt_simplifier_spec.rb
```

Expected: a spec prova que as asserções rejeitam os mutantes e aceita o serviço real.

- [x] **Step 3: Adicionar `pbt` 0.7.0 e escrever property spec**

Adicionar `gem "pbt", "0.7.0"` ao grupo de teste. Gerar IDs UUID v7 canônicos, saldos inteiros com soma zero, zeros e empates; executar 250 casos com `worker: :none`, seed visível e shrinking padrão.

- [x] **Step 4: Confirmar eficácia e Green**

Run:

```bash
docker compose run --rm web bundle exec rspec spec/services/debt_simplifier_property_spec.rb
```

Expected: controle negativo detectado e 250 casos aprovados contra o serviço real.

---

### Task 6: Isolamento Ruby — issue #28

**Files:**

- Create: `spec/services/debt_simplifier_isolation_spec.rb`

**Interfaces:**

- Consumes: caminho absoluto do serviço e `RbConfig.ruby`.
- Produces: evidência em subprocesso sem constantes `Rails`/`ActiveRecord`.

- [x] **Step 1: Escrever controle negativo**

Executar um script mínimo temporário em `spec/` que referencia `Rails`; exigir que o subprocesso falhe. A fixture não contém algoritmo.

- [x] **Step 2: Exercitar serviço real**

Usar `Open3.capture3(RbConfig.ruby, "-e", script)` para exigir o arquivo real, rejeitar `defined?(Rails)` e `defined?(ActiveRecord)`, executar um caso UUID v7 e serializar a transferência esperada.

- [x] **Step 3: Executar spec**

Run:

```bash
docker compose run --rm web bundle exec rspec spec/services/debt_simplifier_isolation_spec.rb
```

Expected: subprocesso real termina `0`; controle negativo é detectado.

---

### Task 7: Reconciliar issues, documentação e gate

**Files:**

- Modify: `PROJECT.md`
- Modify: `README.md`
- Modify: `docs/00-index.md`
- Modify: `docs/02-projeto-quitando.md`
- Modify: `docs/03-quitando-domain-architecture.md`
- Modify: `docs/05-quitando-roadmap-implementacao.md`
- Modify: `docs/07-quitando-decisoes-consolidadas.md`
- Create: `docs/adr/0014-postgresql-uuid-v7-identifiers.md`

**Interfaces:**

- Consumes: evidências Red/Green e gate completo.
- Produces: repositório e GitHub Project coerentes, Fase 1 concluída e Fase 2 pronta.

- [x] **Step 1: Atualizar issues**

Atualizar `#20`, `#25`, `#27`, `#28`, `#7` e corrigir `\n` literais em `#26–#28`. Em cada tarefa registrar contrato, Red/Green ou controle negativo, comandos, resultados, ausência de fallback e riscos.

- [x] **Step 2: Promover sequencialmente**

Cada issue passa `Ready → In progress → Review → Done`; somente a próxima dependência concluída vai a `Ready`. Manter campo `Dependency` e relações nativas coerentes.

- [x] **Step 3: Executar gate fresco**

Run:

```bash
docker compose run --rm web bundle exec rspec spec/services/debt_simplifier_spec.rb
docker compose run --rm web bundle exec rspec spec/services/debt_simplifier_property_spec.rb
docker compose run --rm web bundle exec rspec spec/services/debt_simplifier_isolation_spec.rb
docker compose run --rm web bundle exec rspec spec/services
docker compose run --rm web bin/ci
```

Expected: todas as execuções com exemplos reais e `0 failures`; lint e auditorias aprovados.

- [x] **Step 4: Inspeção PostgreSQL final**

Run:

```bash
docker compose exec -T db psql -X -v ON_ERROR_STOP=1 -P pager=off -U quitando -d quitando_test -c '\d+ users' -c "SELECT id, uuid_extract_version(id) FROM users ORDER BY created_at DESC LIMIT 1;"
```

Expected: `users.id uuid`, default `uuidv7()`, versão `7`.

- [x] **Step 5: Fechar fase somente após o gate**

Mover pré-requisito e `#20–#28` para `Done`, fechar as issues como concluídas, atualizar checklist e evidências de `#6`, mover `#6` para `Done`, `#7` para `Ready`, e registrar “Fase 1 concluída; Fase 2 pronta e não iniciada” em `PROJECT.md` e README sem apresentar o MVP como funcional.

- [ ] **Step 6: Preparar fechamento da branch**

Executar `superpowers:verification-before-completion` e depois `superpowers:finishing-a-development-branch`, preservando a worktree até a escolha explícita do usuário.
