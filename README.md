# Quitando

O Quitando ajuda grupos que já confiam uns nos outros a encerrar despesas compartilhadas com clareza: registra os gastos, calcula saldos líquidos e propõe um plano de quitação com menos transferências.

> Menos contas para reconstruir, menos transferências para coordenar e mais clareza para encerrar as contas do grupo.

## Status

O projeto está em construção, na **Fase 0 — Fundação do projeto**. A visão e os contratos do MVP já estão documentados; as funcionalidades financeiras ainda serão implementadas por fases e não devem ser consideradas disponíveis neste momento.

## Como funciona

```text
despesas ativas
-> saldo oficial
-> pagamentos reportados
-> saldo projetado
-> plano restante
-> confirmações
-> grupo quitado
```

O aplicativo diferencia conceitos que parecem semelhantes, mas têm efeitos distintos:

- **Saldo oficial:** posição líquida baseada em despesas válidas e pagamentos confirmados.
- **Pagamento reportado:** declaração de transferência enviada, ainda aguardando confirmação.
- **Saldo projetado:** saldo oficial ajustado pelos pagamentos reportados.
- **Plano de quitação:** sugestões temporárias calculadas a partir do saldo projetado.
- **Pagamento confirmado:** fato incorporado ao ledger oficial.

Uma sugestão nunca é tratada como pagamento realizado. O destinatário sugerido também pode ser diferente de quem pagou uma despesa específica: o plano compensa o saldo líquido de todo o grupo.

## Princípios do domínio

- Valores monetários usam inteiros na menor unidade da moeda; `float` não é usado.
- A soma das shares de uma despesa é sempre igual ao seu valor.
- A soma dos saldos oficiais e dos projetados é sempre zero.
- Somente pagamentos `confirmed` alteram o saldo oficial.
- Pagamentos `reported` alteram apenas a projeção e o plano restante.
- O algoritmo padrão é guloso, determinístico e gera no máximo `m - 1` transferências para `m` participantes com saldo diferente de zero. Ele não promete o mínimo matemático absoluto.
- Fatos financeiros são auditáveis: uma correção anula a despesa original e cria uma substituta; não sobrescreve campos financeiros históricos.

## Escopo do MVP

O MVP prevê autenticação, grupos com memberships e convites internos, despesas divididas igualmente ou por valor exato, ledger, plano de quitação, pagamentos reportados/confirmados/cancelados, histórico auditável, HTML funcional e atualizações progressivas com Hotwire.

O app é voltado a amigos, familiares, casais, colegas de casa e pequenas equipes com confiança pré-existente. Não é um banco, prova jurídica ou produto para relações adversariais.

Ficam fora do MVP, entre outros: participantes sem conta, links públicos, multi-moeda, integrações Pix/Stripe, disputas, reversão de pagamento confirmado, pagamentos fora do plano atual e API pública. Suporte a múltiplos idiomas é um objetivo pós-MVP e não altera o ledger nem a moeda do grupo.

## Stack

- Ruby 4.0.6 e Rails 8.1
- PostgreSQL
- Hotwire (Turbo e Stimulus)
- Solid Queue, Solid Cable e Solid Cache
- Kamal para deploy

## Desenvolvimento local

Pré-requisitos: Ruby na versão indicada em [`.ruby-version`](./.ruby-version), PostgreSQL em execução e dependências de compilação do `pg` instaladas.

```bash
bin/setup --skip-server
bin/dev
```

O banco de desenvolvimento padrão é `quitado_development`. A configuração está em [`config/database.yml`](./config/database.yml); ajuste as credenciais locais ou use `DATABASE_URL` quando necessário.

Para preparar o banco separadamente:

```bash
bin/rails db:prepare
```

## Verificação

O comando de integração contínua disponível hoje é:

```bash
bin/ci
```

Ele prepara o ambiente e executa lint, auditorias de dependências e segurança, testes Rails e seeds de teste. A estratégia de specs do produto prevê RSpec como parte da fundação do projeto; consulte o roadmap para o gate vigente.

## Documentação

- [Contexto do projeto](./PROJECT.md)
- [Especificação do produto](./docs/02-projeto-quitando.md)
- [Domínio, ledger e arquitetura](./docs/03-quitando-domain-architecture.md)
- [UX e fluxos de interação](./docs/04-quitando-ux-ui.md)
- [Roadmap de implementação e estratégia de specs](./docs/05-quitando-roadmap-implementacao.md)
- [Decisões consolidadas](./docs/07-quitando-decisoes-consolidadas.md)
- [Índice completo da documentação](./docs/00-index.md)

Para contribuir ou alterar o código, leia primeiro as [instruções operacionais](./AGENTS.md). Elas definem a ordem de leitura, os invariantes financeiros e as verificações exigidas em cada fase.
