# ADR-0010 — Uma moeda por grupo no MVP

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

Multi-moeda exige taxa, fonte, timestamp, moeda de liquidação, arredondamento cambial e políticas de correção. Isso desviaria o MVP do núcleo de ledger e quitação.

## Decisão

Cada grupo terá um único `currency_code`. Despesas, shares e pagamentos usam essa moeda. A moeda torna-se imutável após a primeira atividade financeira.

## Consequências

O domínio monetário inicial permanece simples e exato. Viagens internacionais com conversão ficam fora do MVP. Introduzir multi-moeda exigirá novo ADR e modelo explícito de câmbio.

## Alternativas consideradas

- Taxa manual por despesa: adiada porque ainda exige moeda-base e reconciliação.
- Grupo sem moeda fixa: rejeitado por tornar saldos incomparáveis.

## Documentos relacionados

- [`../02-projeto-quitando.md`](../02-projeto-quitando.md)
- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
