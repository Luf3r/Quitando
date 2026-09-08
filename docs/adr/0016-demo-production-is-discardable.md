# ADR-0016 — Produção demo é descartável

- **Status:** Accepted
- **Data:** 2026-08-28
- **Complementa:** ADR-0008

## Contexto

O Quitando precisa de uma demonstração pública reproduzível para explicar o produto e exercitar jornadas reais. Misturar essa demonstração com dados duráveis transformaria contas e fatos financeiros de exemplo em dados que parecem reais e tornaria o reset uma operação insegura.

## Decisão

A produção pública demo é exclusivamente demo-only e descartável. Ela usa banco e deploy separados, com `QUITANDO_DEMO_MODE=true`, e faz reset integral do cenário canônico a cada seis horas. Dados reais duráveis exigem banco e deploy distintos com `QUITANDO_DEMO_MODE=false`.

O instalador e o resetter são transacionais, usam os comandos reais do domínio e compartilham advisory lock PostgreSQL. O reset manual exige `CONFIRM_DEMO_RESET=quitando-demo-only`; antes de qualquer `TRUNCATE`, `QUITANDO_DEMO_DATABASE_NAME` deve coincidir exatamente com o banco atual. Modo demo desligado, confirmação ausente, banco não autorizado, timeout ou seed inválido são falhas explícitas, nunca sucesso degradado.

## Consequências

- contas e fatos do cenário público podem ser removidos integralmente sem prometer retenção;
- sessões criadas antes de um reset deixam de ser válidas e retornam ao login;
- a instalação e o reset preservam as regras existentes de centavos, ledger, append-only, locks, idempotência, autorização e efeitos pós-commit;
- o cenário não altera fórmulas, estados financeiros, `financial_state_version` nem permissões financeiras;
- uma operação real precisa de infraestrutura separada e não pode reutilizar o banco demo.

## Alternativas consideradas

- Compartilhar o banco demo com dados duráveis: rejeitada porque um reset integral poderia remover fatos reais.
- Preservar dados demo indefinidamente: rejeitada porque perde reprodutibilidade e aumenta o risco de a demonstração ser interpretada como ambiente durável.
- Fazer reset parcial ou por registros conhecidos: rejeitada porque deixa estado residual e não prova a reconstrução completa do cenário.
- Ocultar erro de reset e continuar servindo um cenário possivelmente parcial: rejeitada porque simularia sucesso sem integridade demonstrável.

## Documentos relacionados

- [`../02-projeto-quitando.md`](../02-projeto-quitando.md)
- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../04-quitando-ux-ui.md`](../04-quitando-ux-ui.md)
- [`../05-quitando-roadmap-implementacao.md`](../05-quitando-roadmap-implementacao.md)
- [`../07-quitando-decisoes-consolidadas.md`](../07-quitando-decisoes-consolidadas.md)
