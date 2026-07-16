# ADR-0008 — HTTP é a fonte de reconciliação

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

Conexões WebSocket podem cair e broadcasts podem não ser entregues. O estado financeiro não pode depender da memória do navegador ou da sequência perfeita de streams.

## Decisão

Toda página e comando deve funcionar por HTTP e reconstruir o estado atual a partir do servidor. Turbo Streams e Action Cable são melhorias progressivas. Broadcasts notificam mudanças depois do commit, mas não são fonte de verdade.

## Consequências

Reload e reconexão corrigem qualquer perda de evento. A implementação HTTP precede real-time no roadmap. Falha de broadcast não desfaz persistência bem-sucedida.

## Alternativas consideradas

- SPA com estado financeiro no cliente: rejeitada por complexidade e risco de divergência.
- Polling como mecanismo principal: possível, mas inferior para feedback imediato; permanece fallback em jobs futuros.

## Documentos relacionados

- [`../04-quitando-ux-ui.md`](../04-quitando-ux-ui.md)
- [`../05-quitando-roadmap-implementacao.md`](../05-quitando-roadmap-implementacao.md)
