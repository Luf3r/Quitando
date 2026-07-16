# ADR-0004 — Planos de quitação são derivados no MVP

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

O plano muda sempre que uma despesa, pagamento reportado, confirmação ou cancelamento altera os saldos. Persistir sugestões cria problemas de validade, sincronização e histórico de planos obsoletos.

## Decisão

No MVP, o plano não será persistido. `DebtSimplifier` calcula transferências sob demanda a partir dos saldos projetados. Pagamentos são fatos persistidos; sugestões não são.

## Consequências

A leitura sempre reflete o estado financeiro atual. A aplicação recalcula o plano em comandos sensíveis. Cache ou persistência futura exigirá versão, validade e política de invalidação.

## Alternativas consideradas

- Persistir cada plano: rejeitado no MVP por complexidade.
- Persistir apenas a transferência escolhida: o pagamento reportado já cumpre esse papel como fato de workflow.

## Documentos relacionados

- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../07-quitando-decisoes-consolidadas.md`](../07-quitando-decisoes-consolidadas.md)
