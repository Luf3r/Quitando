# ADR-0012 — `User` é o participante financeiro no MVP

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

Suportar pessoas sem conta exige uma entidade `Participant` separada, convite externo, migração posterior para usuário e autorização por token. Isso amplia significativamente o domínio.

## Decisão

No MVP, memberships, shares e pagamentos referenciam `User`. Convites internos só podem ser enviados a contas existentes e não criam participação financeira antes da aceitação.

## Consequências

A modelagem é mais simples e todas as ações possuem identidade autenticada. Convidados e links públicos exigirão novo ADR e provável migração das referências de `User` para `Participant`.

## Alternativas consideradas

- `Participant` desde o início: tecnicamente mais flexível, mas rejeitado para reduzir escopo.
- Shares para e-mail sem conta: rejeitadas porque criariam dívida sem identidade e fluxo de aceite.

## Documentos relacionados

- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../07-quitando-decisoes-consolidadas.md`](../07-quitando-decisoes-consolidadas.md)
