# ADR-0003 — Algoritmo guloso como padrão

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

Minimizar exatamente o número de transferências é combinatoriamente caro. O produto precisa responder rapidamente e de forma previsível para grupos comuns.

## Decisão

Usar um algoritmo guloso determinístico que casa o maior devedor com o maior credor. Com filas de prioridade, a implementação opera em `O(m log m)` e produz no máximo `m - 1` transferências.

## Consequências

O modo padrão simplifica, mas não promete ótimo matemático. Empates precisam de ordem estável. Um solver exato poderá existir depois, com timeout, fallback e versionamento.

## Alternativas consideradas

- Solver exato como padrão: rejeitado por latência imprevisível.
- Preservar apenas dívidas bilaterais históricas: rejeitado como padrão porque reduz menos transferências.
- Heurísticas não determinísticas: rejeitadas por UX e testes instáveis.

## Documentos relacionados

- [`../02-projeto-quitando.md`](../02-projeto-quitando.md)
- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
