# ADR-0013 — Internacionalização é uma responsabilidade de apresentação

- **Status:** Accepted
- **Data:** 2026-07-15

## Contexto

O produto deverá oferecer múltiplos idiomas depois do MVP. Idioma, formato de data, separadores numéricos e convenções visuais variam por locale, enquanto moeda, saldos, shares e pagamentos pertencem ao domínio financeiro do grupo.

Misturar locale com moeda ou regras do ledger poderia causar comportamentos incorretos, como inferir `currency_code` pelo idioma da interface, alterar valores persistidos ao trocar de locale ou interpretar entradas monetárias por meio de `float`.

Mesmo com apenas português no MVP, textos financeiros hardcoded e formatação espalhada por views, controllers e componentes criariam dívida técnica desnecessária para a evolução internacional.

## Decisão

Internacionalização será tratada como uma responsabilidade de apresentação.

- O locale controla textos, mensagens de validação, nomes de estados, datas, números e a apresentação de valores monetários.
- O locale não altera despesas, shares, pagamentos, saldos, plano de quitação nem qualquer outra regra do ledger.
- A moeda é definida por `Group.currency_code` e nunca é inferida automaticamente do locale do usuário.
- Trocar o idioma ou a região de apresentação não modifica fatos financeiros persistidos.
- Valores monetários continuam armazenados e calculados em unidades inteiras da menor denominação da moeda.
- A entrada monetária localizada deve ser convertida diretamente de texto para inteiro por um parser explícito, sem passar por `float`.
- Textos de domínio e interface não devem ser concatenados de forma que impeça tradução. Frases completas usam chaves de tradução com interpolação.
- Formatação de moeda, datas e números deve permanecer centralizada em helpers, presenters ou componentes apropriados.
- O MVP pode disponibilizar apenas `pt-BR`, mas novas mensagens devem preferencialmente nascer em arquivos de locale, especialmente nos fluxos financeiros centrais.
- A disponibilização de um novo idioma exige cobertura das jornadas e mensagens críticas de saldo oficial, saldo projetado, sugestão, pagamento reportado, confirmação, cancelamento e grupo quitado.

Internacionalização e multi-moeda são evoluções independentes. Uma interface em inglês pode operar um grupo em BRL, e uma interface em português poderá futuramente operar um grupo em outra moeda sem alterar a semântica do locale.

## Consequências

A arquitetura poderá adicionar idiomas sem alterar o ledger ou recalcular dados financeiros. A separação reduz o risco de bugs em dinheiro causados por formatação regional e mantém a decisão de uma moeda por grupo independente da linguagem da interface.

O projeto precisará manter chaves de tradução, formatação centralizada e testes de apresentação. O parser monetário deverá receber locale ou convenção explícita, rejeitar entradas ambíguas e preservar os valores inteiros esperados.

O uso de arquivos de locale desde o início adiciona uma pequena disciplina ao MVP, mas evita uma migração ampla de strings hardcoded depois.

## Alternativas consideradas

- **Inferir moeda pelo locale:** rejeitado porque idioma, região do usuário e moeda do grupo são conceitos independentes.
- **Adicionar internacionalização somente após o MVP, mantendo strings hardcoded até lá:** rejeitado para mensagens financeiras centrais, pois aumentaria retrabalho e risco de traduções incompletas.
- **Persistir valores já formatados:** rejeitado porque formatação é dependente de locale e não deve fazer parte do fato financeiro.
- **Usar `float` durante parsing localizado:** rejeitado por imprecisão e por violar o contrato monetário do domínio.

## Documentos relacionados

- [`../02-projeto-quitando.md`](../02-projeto-quitando.md)
- [`../03-quitando-domain-architecture.md`](../03-quitando-domain-architecture.md)
- [`../04-quitando-ux-ui.md`](../04-quitando-ux-ui.md)
- [`../05-quitando-roadmap-implementacao.md`](../05-quitando-roadmap-implementacao.md)
- [`../07-quitando-decisoes-consolidadas.md`](../07-quitando-decisoes-consolidadas.md)
- [`0001-money-in-integer-minor-units.md`](0001-money-in-integer-minor-units.md)
- [`0010-one-currency-per-group-in-mvp.md`](0010-one-currency-per-group-in-mvp.md)
