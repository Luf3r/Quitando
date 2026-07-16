# ADR-0002 — Saldos oficial e projetado separados

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

Um pagamento declarado pode ter sido enviado, mas ainda não confirmado pelo recebedor. Ignorá-lo faria o plano sugerir a mesma transferência novamente; tratá-lo como confirmado falsificaria o ledger oficial.

## Decisão

Manter dois cálculos derivados: saldo oficial usa despesas ativas, shares e pagamentos `confirmed`; saldo projetado aplica também os pagamentos `reported`. O plano acionável usa o saldo projetado.

## Consequências

A interface precisa explicar claramente os dois estados. Cancelar um report restaura a projeção. Confirmar move o efeito para o ledger oficial sem alterar o resultado projetado esperado.

## Alternativas consideradas

- Considerar `reported` como oficial: rejeitado por falta de confirmação.
- Ignorar `reported` no plano: rejeitado por duplicar sugestões.
- Reservar valores em uma tabela de plano persistida: adiado; aumenta complexidade e invalidação.

## Documentos relacionados

- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../04-quitando-ux-ui.md`](../04-quitando-ux-ui.md)
