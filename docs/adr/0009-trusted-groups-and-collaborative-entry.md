# ADR-0009 — Grupos de confiança e registro colaborativo

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

O MVP permite que um membro registre uma despesa e indique outro membro como pagador, sem aprovação prévia ou disputa formal. Isso facilita viagens e reconstrução colaborativa, mas não protege relações adversariais.

## Decisão

O produto será explicitamente destinado a grupos com confiança pré-existente. `created_by_user_id` e `paid_by_user_id` serão separados e visíveis. O pagador indicado recebe destaque contextual no aplicativo. Contestação e aprovação ficam fora do MVP.

## Consequências

O produto não deve ser apresentado como prova bancária ou plataforma entre desconhecidos. Transparência e auditoria reduzem erros, mas não substituem mecanismos antifraude.

## Alternativas consideradas

- Exigir que apenas o próprio pagador registre: rejeitado por reduzir colaboração.
- Aprovação obrigatória de toda despesa: adiada por fricção e complexidade.
- Owner registrar por todos sem autoria visível: rejeitado por baixa transparência.

## Documentos relacionados

- [`../01-quitando-problema-casos-de-uso.md`](../01-quitando-problema-casos-de-uso.md)
- [`../04-quitando-ux-ui.md`](../04-quitando-ux-ui.md)
