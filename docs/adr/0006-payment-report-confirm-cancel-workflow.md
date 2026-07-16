# ADR-0006 — Workflow reportar, confirmar ou cancelar pagamento

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

Uma declaração unilateral não prova recebimento, mas ignorá-la causa repetição no plano. O fluxo precisa distinguir envio alegado de recebimento confirmado.

## Decisão

O pagamento nasce como `reported`. O recebedor pode movê-lo para `confirmed`; pagador ou recebedor podem movê-lo para `cancelled` com ator e motivo. `confirmed` e `cancelled` são terminais no MVP.

## Consequências

Somente `confirmed` altera o saldo oficial; `reported` altera a projeção. A ausência de reversão de `confirmed` exige confirmação explícita e será tratada em fase posterior por evento compensatório vinculado.

## Alternativas consideradas

- Confirmação unilateral: rejeitada por confiança insuficiente.
- Aprovação de despesa antes do ledger: adiada por fricção e novos estados.
- Reabrir pagamento confirmado: rejeitado por perda de auditabilidade.

## Documentos relacionados

- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../04-quitando-ux-ui.md`](../04-quitando-ux-ui.md)
