# ADR-0014 — Identificadores UUID v7 gerados pelo PostgreSQL

- **Status:** Accepted
- **Data:** 2026-07-19

## Contexto

As identidades persistentes precisam permanecer uniformes entre o domínio Ruby puro e as entidades Rails que serão introduzidas a partir da Fase 2. O PostgreSQL 18 fornece `uuidv7()` nativamente, enquanto o default implícito do adapter Rails para uma PK `uuid` usa `gen_random_uuid()`, que gera UUID v4.

Além do tipo persistente, o `DebtSimplifier` precisa de uma ordem total estável para desempatar participantes sem depender da ordem do `Hash`, do banco ou da memória.

Os bancos existentes contêm somente dados descartáveis de desenvolvimento e teste. Portanto, a migration inicial pode ser ajustada e os bancos recriados sem conversão de dados.

## Decisão

- todas as chaves primárias das entidades usam o tipo PostgreSQL `uuid`;
- toda migration declara explicitamente `default: -> { "uuidv7()" }` na chave primária;
- todas as foreign keys usam o tipo `uuid` da chave referenciada;
- generators Rails usam `primary_key_type: :uuid`, mas essa configuração não substitui o default explícito por migration;
- o PostgreSQL 18 é o único gerador de PKs persistentes;
- Ruby representa esses identificadores como strings UUID v7 canônicas e minúsculas, com variante RFC válida;
- o `DebtSimplifier` desempata magnitudes iguais pela ordem lexicográfica crescente dessas strings.

O formato público aceito é:

```text
xxxxxxxx-xxxx-7xxx-[89ab]xxx-xxxxxxxxxxxx
```

com caracteres hexadecimais minúsculos.

## Consequências

- uma PK sem `uuidv7()` explícito viola o contrato mesmo que seu tipo seja `uuid`;
- `gen_random_uuid()` não é aceito como default de PK;
- factories omitem o ID e exercitam a geração real do banco;
- specs de persistência verificam `uuid_extract_version(id) = 7`;
- o `DebtSimplifier` pode validar e ordenar IDs sem carregar Rails ou ActiveRecord;
- migrations e FKs da Fase 2 precisam preservar o tipo `uuid`;
- a ordenação cronológica aproximada do UUID v7 não transforma o identificador em fonte normativa de tempo; timestamps continuam explícitos.

## Alternativas consideradas

- `bigint` como PK: rejeitado porque diverge do contrato público escolhido para as identidades.
- UUID v4 com `gen_random_uuid()`: rejeitado porque não atende à ordenação temporal aproximada e ao padrão uniforme decidido.
- geração na aplicação: rejeitada porque duplica responsabilidade e permite defaults divergentes entre caminhos de escrita.
- aceitar qualquer UUID no serviço: rejeitado porque esconderia incompatibilidade entre a API pura e a persistência.

## Documentos relacionados

- [`../02-projeto-quitando.md`](../02-projeto-quitando.md)
- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../05-quitando-roadmap-implementacao.md`](../05-quitando-roadmap-implementacao.md)
- [`../07-quitando-decisoes-consolidadas.md`](../07-quitando-decisoes-consolidadas.md)
- [`0003-greedy-settlement-is-default.md`](./0003-greedy-settlement-is-default.md)
