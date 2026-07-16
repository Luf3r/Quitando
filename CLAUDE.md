# CLAUDE.md — Quitando

Este arquivo é um adaptador curto. A fonte operacional compartilhada é [`AGENTS.md`](./AGENTS.md); o contexto compacto está em [`PROJECT.md`](./PROJECT.md).

Antes de alterar código:

1. leia `PROJECT.md`;
2. leia `AGENTS.md` por completo;
3. localize a fase atual em [`docs/05-quitando-roadmap-implementacao.md`](./docs/05-quitando-roadmap-implementacao.md);
4. consulte as seções normativas relevantes de [`docs/03-quitando-domain-architecture.md`](./docs/03-quitando-domain-architecture.md).

Regras essenciais:

- siga TDD e os gates do roadmap;
- não use `float` para dinheiro;
- não confunda saldo, projeção, sugestão e pagamento confirmado;
- não persista sugestões no MVP;
- execute autorização, versão e idempotência no backend;
- mantenha HTTP como caminho completo antes de real-time;
- não implemente itens fora do MVP sem atualizar os documentos;
- ao concluir, informe testes realmente executados e riscos restantes.

Não replique novas regras aqui. Atualize `AGENTS.md` e os documentos normativos para evitar divergência.
