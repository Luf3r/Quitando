# ADR-0005 — Correções financeiras de despesas são imutáveis

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

Alterar silenciosamente valor, pagador ou shares reescreve o passado e dificulta explicar como saldos e pagamentos foram produzidos.

## Decisão

Campos financeiros de uma despesa não serão sobrescritos. Uma correção anula o registro original e cria uma despesa substituta na mesma transação, com ator, motivo e vínculo `replaces_expense_id`.

## Consequências

O histórico permanece auditável e o ledger é recalculável. A UX precisa mostrar a cadeia de correção. Campos apenas descritivos podem seguir política de edição separada com auditoria.

## Alternativas consideradas

- Edição in-place antes de pagamentos: rejeitada para manter uma regra única.
- Exclusão física: rejeitada por perda de histórico.
- Evento contábil genérico para toda correção: possível no futuro, mas complexo para o MVP.

## Documentos relacionados

- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../04-quitando-ux-ui.md`](../04-quitando-ux-ui.md)
