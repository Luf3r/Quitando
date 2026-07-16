# ADR-0001 — Dinheiro em unidades inteiras

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

O sistema calcula shares, saldos e pagamentos. Valores binários de ponto flutuante não representam corretamente todos os decimais e podem quebrar conservação, comparação e arredondamento.

## Decisão

Todos os valores monetários serão armazenados e calculados em unidades inteiras da menor denominação da moeda, normalmente centavos. Colunas monetárias usarão `bigint`. A entrada decimal será convertida diretamente para inteiro, sem passar por `float`.

## Consequências

A soma das shares e dos saldos pode ser verificada exatamente. Regras de arredondamento precisam ser explícitas e determinísticas. Formatação e parsing monetário exigem uma camada própria.

## Alternativas consideradas

- `float`: rejeitado por imprecisão.
- `decimal/numeric` em todo o domínio: possível, mas desnecessário para uma moeda de duas casas no MVP e mais fácil de misturar com escalas distintas.

## Documentos relacionados

- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../05-quitando-roadmap-implementacao.md`](../05-quitando-roadmap-implementacao.md)
