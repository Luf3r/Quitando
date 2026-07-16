# Quitando — Índice da Documentação

Este é o ponto de entrada dos documentos detalhados. Ele define a ordem de leitura, a precedência das fontes e o mapa de ADRs.

## Navegação rápida

- [Leitura inicial](#1-leitura-inicial)
- [Ordem completa](#2-ordem-completa)
- [Precedência documental](#3-precedência-documental)
- [Architecture Decision Records](#4-architecture-decision-records)
- [Arquivos para agentes](#5-arquivos-para-agentes)
- [Manutenção](#6-manutenção)

---

## 1. Leitura inicial

Para começar a desenvolver:

1. leia [`../PROJECT.md`](../PROJECT.md);
2. siga as regras de [`../AGENTS.md`](../AGENTS.md);
3. localize a etapa atual no [roadmap de implementação](./05-quitando-roadmap-implementacao.md);
4. consulte as seções necessárias do [documento de domínio](./03-quitando-domain-architecture.md);
5. leia o ADR relacionado quando a tarefa tocar uma decisão arquitetural.

Para compreender o produto antes da implementação, comece pelo documento de problema e siga a ordem completa abaixo.

---

## 2. Ordem completa

1. [Problema, Casos de Uso e Hipóteses de Produto](./01-quitando-problema-casos-de-uso.md) — dor real, contextos, riscos e hipóteses.
2. [Especificação do Produto](./02-projeto-quitando.md) — promessa, MVP, não escopo e roadmap funcional.
3. [Domínio, Ledger e Arquitetura](./03-quitando-domain-architecture.md) — fórmulas, invariantes, estados, persistência e concorrência.
4. [UI/UX e Fluxos de Interação](./04-quitando-ux-ui.md) — telas, linguagem, acessibilidade e comportamentos observáveis.
5. [Roadmap de Implementação e Estratégia de Specs](./05-quitando-roadmap-implementacao.md) — ordem técnica, dependências, specs e gates.
6. [Relatório de Verificação Documental](./06-quitando-relatorio-verificacao.md) — auditorias realizadas, limitações e riscos restantes.
7. [Decisões Consolidadas](./07-quitando-decisoes-consolidadas.md) — resumo operacional das decisões vigentes.

---

## 3. Precedência documental

Em caso de divergência:

1. **domínio e arquitetura** prevalecem para fórmulas, invariantes, estados e consistência;
2. **especificação do produto** prevalece para escopo, prioridade e promessa;
3. **roadmap técnico** prevalece para ordem de construção, specs e gates;
4. **UX/UI** prevalece para linguagem e comportamento observável;
5. **problema e casos de uso** prevalecem para hipóteses e alegações de valor;
6. **ADRs** explicam decisões arquiteturais aceitas e como alterá-las.

Nenhuma divergência deve ser resolvida silenciosamente. Atualize as fontes afetadas junto com o código.

---

## 4. Architecture Decision Records

Os ADRs ficam em [`adr/`](./adr/) e são curtos, focados e históricos.

1. [ADR-0001 — Dinheiro em unidades inteiras](./adr/0001-money-in-integer-minor-units.md)
2. [ADR-0002 — Saldos oficial e projetado separados](./adr/0002-separate-official-and-projected-balances.md)
3. [ADR-0003 — Algoritmo guloso como padrão](./adr/0003-greedy-settlement-is-default.md)
4. [ADR-0004 — Planos derivados e não persistidos no MVP](./adr/0004-settlement-plans-are-derived.md)
5. [ADR-0005 — Correções financeiras imutáveis](./adr/0005-financial-expense-corrections-are-immutable.md)
6. [ADR-0006 — Workflow reportar, confirmar ou cancelar](./adr/0006-payment-report-confirm-cancel-workflow.md)
7. [ADR-0007 — Versão financeira, locks e idempotência](./adr/0007-financial-version-locking-and-idempotency.md)
8. [ADR-0008 — HTTP como fonte de reconciliação](./adr/0008-http-is-the-reconciliation-source.md)
9. [ADR-0009 — Grupos de confiança e registro colaborativo](./adr/0009-trusted-groups-and-collaborative-entry.md)
10. [ADR-0010 — Uma moeda por grupo no MVP](./adr/0010-one-currency-per-group-in-mvp.md)
11. [ADR-0011 — Pagamentos somente a partir do plano atual](./adr/0011-payments-must-follow-current-plan.md)
12. [ADR-0012 — `User` como participante financeiro no MVP](./adr/0012-user-is-the-financial-participant-in-mvp.md)

---

## 5. Arquivos para agentes

Na raiz do repositório:

- [`../PROJECT.md`](../PROJECT.md) — contexto compacto e milestone atual;
- [`../AGENTS.md`](../AGENTS.md) — regras operacionais compartilhadas;
- [`../CLAUDE.md`](../CLAUDE.md) — adaptador curto para Claude Code;
- [`../CODEX.md`](../CODEX.md) — adaptador curto para Codex.

`CLAUDE.md` e `CODEX.md` não devem duplicar regras. Mudanças compartilhadas pertencem a `AGENTS.md`; decisões de produto e domínio permanecem nos documentos normativos.

---

## 6. Manutenção

- Preserve a numeração `00` a `07`; novos documentos temáticos usam o próximo número apenas quando houver uma responsabilidade realmente nova.
- ADRs são append-only: uma mudança material cria um novo ADR e marca o anterior como superseded.
- Atualize links, `PROJECT.md`, `AGENTS.md` e este índice ao mover ou renomear arquivos.
- Evite versões “short” paralelas dos documentos; use os resumos da raiz como camada compacta.
