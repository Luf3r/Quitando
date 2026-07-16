# ADR-0007 — Versão financeira, locks e idempotência

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

Reports dependem de um plano calculado que pode mudar entre leitura e gravação. Duplo clique e ações concorrentes podem reservar o mesmo valor ou repetir transições.

## Decisão

Usar `financial_state_version` monotônica no grupo, serialização por lock do grupo em comandos financeiros e chaves de idempotência com fingerprint canônico do payload. Comandos dependentes de plano revalidam a versão e recalculam dentro da transação.

## Consequências

Ações obsoletas falham de forma orientada e apresentam o estado atual. Mesma chave e payload retornam o resultado anterior; mesma chave com payload diferente gera conflito. Broadcasts ocorrem após commit.

## Alternativas consideradas

- Optimistic locking apenas nos registros individuais: insuficiente para invariantes agregadas do grupo.
- Lock global: rejeitado por contenção desnecessária.
- Idempotência apenas no frontend: rejeitada por não proteger retries e concorrência.

## Documentos relacionados

- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../05-quitando-roadmap-implementacao.md`](../05-quitando-roadmap-implementacao.md)
