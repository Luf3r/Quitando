# ADR-0015 — BRL é a única moeda suportada no MVP

- **Status:** Accepted
- **Data:** 2026-08-08
- **Complementa:** ADR-0010

## Contexto

O ADR-0010 fixa uma moeda por grupo, mas o schema inicial ainda aceitava qualquer `currency_code`. Essa abertura permite persistir grupos incompatíveis com o escopo monetário efetivamente suportado pelo MVP e torna a futura introdução de câmbio parecer uma variação de validação, quando exige decisões de domínio próprias.

## Decisão

No MVP, `groups.currency_code` é sempre `BRL`. O PostgreSQL protege a regra com `CHECK (currency_code = 'BRL')`; dados existentes incompatíveis fazem a migration falhar, sem normalização ou coerção. Não há seletor de moeda, conversão, taxa de câmbio ou fato financeiro em outra moeda.

Esta decisão complementa, sem substituir, o ADR-0010: cada grupo continua tendo uma única moeda, agora determinada como BRL durante o MVP.

## Consequências

- despesas, shares e pagamentos do MVP permanecem comparáveis em centavos de BRL;
- uma futura multi-moeda exige novo ADR para moeda-base, taxa, instante da taxa, arredondamento e correção;
- falha de migration por dado legado não BRL é visível e exige decisão operacional, em vez de alterar o dado silenciosamente.

## Alternativas consideradas

- Aceitar códigos ISO arbitrários sem conversão: rejeitada porque persiste estados que o ledger e a interface não suportam.
- Converter registros existentes para BRL na migration: rejeitada porque inventaria equivalência cambial e reescreveria fatos.
- Remover `currency_code`: rejeitada porque o campo explicita a fronteira para a futura decisão de multi-moeda.

## Documentos relacionados

- [`0010-one-currency-per-group-in-mvp.md`](./0010-one-currency-per-group-in-mvp.md)
- [`../02-projeto-quitando.md`](../02-projeto-quitando.md)
- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../04-quitando-ux-ui.md`](../04-quitando-ux-ui.md)
- [`../07-quitando-decisoes-consolidadas.md`](../07-quitando-decisoes-consolidadas.md)
