# ADR-0011 — Pagamentos seguem o plano atual no MVP

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

Permitir transferências arbitrárias exige decidir como aceitar pagamentos entre pessoas que não possuem sinais compatíveis, como tratar excesso e como explicar efeitos inesperados.

## Decisão

No MVP, um `Payment` só pode ser reportado a partir de uma transferência do plano acionável atual, com `0 < amount <= suggested_amount`. O servidor recalcula e revalida par e valor dentro da transação.

## Consequências

O workflow permanece previsível e a projeção não atravessa regras ambíguas. Pagamentos parciais são permitidos. Flexibilidade fora do plano fica para uma fase posterior com novos invariantes.

## Alternativas consideradas

- Permitir qualquer par e valor: rejeitado por aumentar estados inválidos.
- Exigir apenas pagamentos totais: rejeitado porque pagamentos parciais são plausíveis e simples de modelar dentro da sugestão.

## Documentos relacionados

- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../04-quitando-ux-ui.md`](../04-quitando-ux-ui.md)
