# Task 2 — Integrar pendências ao plano restante

## Contrato da tarefa

- **Fase e gate:** Fase 6, segunda fatia do épico #11. O gate exige que um valor `reported` apareça como pendência e desapareça do plano restante sem alterar o saldo oficial.
- **Fontes normativas:** `PROJECT.md`, `AGENTS.md`, `docs/00-index.md`, `docs/05-quitando-roadmap-implementacao.md` (Fase 6), `docs/03-quitando-domain-architecture.md` (ledger, pagamentos e serviços), `docs/07-quitando-decisoes-consolidadas.md`, ADR 0002 e o brief desta tarefa.
- **Comportamento principal:** `SettlementPlanGenerator.call(group)` calcula uma vez o saldo oficial, lê exclusivamente `group.payments.reported`, projeta esses reports e simplifica o saldo projetado, retornando `Array<DebtSimplifier::Transfer>`.
- **Invariantes:** o saldo oficial e `financial_state_version` não são alterados pela leitura; reports reservam somente a projeção; pagamentos `confirmed` são contabilizados uma vez no oficial; pagamentos `cancelled` não entram; a soma permanece zero.
- **Entradas e fronteiras:** payments persistidos de cenários válidos do plano original, inclusive parciais; reports continuam projetados após nova despesa, inclusive se o saldo troca de sinal. Falhas do ledger, consulta, projetor e simplificador devem propagar sem resultado parcial.
- **Fora do escopo:** comandos de criação, cancelamento e confirmação; validação de reports; lock, idempotência, autorização, HTTP/UI, presenter, snapshot e persistência de plano.
- **Contratos afetados:** domínio, banco e serviço.
- **Impacto documental:** nenhum — implementa contrato normativo já documentado, sem alterar regra, decisão, fase ou capacidade pública além da fatia em execução.

## Matriz de evidência

```text
Contrato solicitado: gerar plano restante a partir do saldo projetado
Comportamento principal: reports aparecem como reserva na projeção e não são sugeridos novamente
Spec que prova o caminho principal: spec/services/settlement_plan_generator_spec.rb
Fallbacks autorizados: nenhum
Specs dos fallbacks: não aplicável
Erros que permanecem visíveis: falhas do ledger, consulta, projeção e simplificador
Evidência de que o fallback não é o caminho padrão: o método propaga falhas e não devolve resultado parcial
```

## Implementado

- `SettlementPlanGenerator` calcula os saldos oficiais uma vez, consulta `group.payments.reported`, aplica `ProjectedBalanceCalculator` e entrega o saldo projetado ao `DebtSimplifier`.
- Não foram adicionados presenter, snapshot, `Payment`, persistência de plano, validação de report, lock, idempotência, autorização, HTTP ou UI.
- A leitura não altera os fatos financeiros, o saldo oficial ou `financial_state_version`.
- As specs persistidas cobrem ausência de reports, report total, parcial, múltiplo, cancelado, confirmado, a equivalência da projeção antes/depois da confirmação e a permanência de report após nova despesa inverter o saldo.

## Fallbacks

Nenhum autorizado.

## Não implementado

Os itens explicitamente fora do escopo acima permanecem para a Fase 7 ou fases posteriores.

## Bloqueios

Nenhum. A primeira tentativa de fixture `cancelled` falhou na constraint real `payments_audit_metadata_matches_status`; a fixture foi corrigida com ator, timestamp e motivo de cancelamento antes de qualquer mudança de produção.

## Evidências

### Red

1. `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/services/settlement_plan_generator_spec.rb`
   - Inicialmente: 15 exemplos, 6 falhas. Cinco eram o Red esperado (o gerador retornava o plano oficial, ignorando reports); uma revelou a fixture `cancelled` incompleta, rejeitada pelo PostgreSQL.
2. Mesmo comando após corrigir somente os metadados obrigatórios da fixture.
   - 15 exemplos, 5 falhas esperadas: report total, parcial, múltiplo, confirmação equivalente e nova despesa com inversão retornavam o plano oficial porque `SettlementPlanGenerator` ainda não chamava o projetor.

### Green e refactor

1. Mesmo comando após a implementação mínima.
   - 15 exemplos, 0 falhas.
2. `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/services/settlement_plan_generator_spec.rb:90`
   - 1 exemplo, 0 falhas: uma consulta nomeada `GroupBalanceCalculator` e leitura de pagamentos com filtro `"payments"."status" = $2`.
3. `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec spec/services/group_balance_calculator_spec.rb spec/services/projected_balance_calculator_spec.rb spec/services/settlement_plan_generator_spec.rb spec/services/settlement_plan_generator_property_spec.rb`
   - Saída 0; executou os contratos relacionados de ledger, projeção, plano e propriedades persistidas.
4. `docker compose run --rm -e RAILS_ENV=test web bin/ci`
   - Saída 0. Schema round-trip, RuboCop (83 arquivos, 0 offenses), bundler-audit, importmap audit, Brakeman, prepare/eager load e RSpec foram executados.
5. `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec --format progress`
   - Saída 0; suíte completa RSpec executada sobre o diff final.

### Arquivos alterados

- `app/services/settlement_plan_generator.rb`
- `spec/services/settlement_plan_generator_spec.rb`
- `.superpowers/sdd/quitando-fase-6-saldo-projetado-plan/task-2-report.md`

### Decisões e preocupações

- O gerador não captura exceções: falhas do ledger, consulta, projetor ou simplificador permanecem visíveis e não devolvem plano parcial.
- Não há fallback autorizado.
- A criação, cancelamento e confirmação transacionais de payments continuam fora do escopo e pertencem à Fase 7.
