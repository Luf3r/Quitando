# Quitando

O Quitando ajuda grupos que já confiam uns nos outros a encerrar despesas compartilhadas com clareza: registra os gastos, calcula saldos líquidos e propõe um plano de quitação com menos transferências.

> Menos contas para reconstruir, menos transferências para coordenar e mais clareza para encerrar as contas do grupo.

## Status

O projeto está em construção. As **Fases 0 e 1** estão concluídas: o `DebtSimplifier` Ruby puro valida UUIDs v7, simplifica saldos de forma determinística e é coberto por exemplos, propriedades e isolamento do framework. A **Fase 2 — Schema e entidades financeiras mínimas** está pronta e não iniciada. Também estão disponíveis o bootstrap Rails, RSpec com exemplos reais, `bin/ci`, checagens de lint e segurança, Docker com PostgreSQL 18, Active Storage/Vips, Devise, Pundit, FactoryBot, parser monetário em centavos e locale `pt-BR`.

Há uma jornada mínima de cadastro e os smoke tests da fundação, mas grupos, despesas, ledger, policies de domínio e demais regras financeiras ainda serão implementados conforme o roadmap. A fundação existente não deve ser apresentada como MVP funcional.

O trabalho é acompanhado no [GitHub Project — Quitando](https://github.com/users/Luf3r/projects/2). O épico da Fase 1 é a issue [#6](https://github.com/Luf3r/Quitando/issues/6), concluída com o pré-requisito UUID v7 [#30](https://github.com/Luf3r/Quitando/issues/30); a próxima fase executável é a [#7](https://github.com/Luf3r/Quitando/issues/7). Status e campos do quadro devem refletir apenas trabalho realmente demonstrado; contratos e gates continuam definidos pela documentação do repositório.

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

- Ruby 4.0.6 e Rails 8.1.3
- PostgreSQL 18
- Hotwire (Turbo e Stimulus)
- Solid Queue, Solid Cable e Solid Cache
- Kamal para deploy

## Desenvolvimento com Docker

Docker Compose é o caminho recomendado para desenvolvimento. Ele usa o [Dockerfile.dev](./Dockerfile.dev), sobe Rails e PostgreSQL 18 em containers separados e não exige Ruby nem PostgreSQL instalados na máquina host.

```bash
cp .env.example .env
docker compose up --build
```

O container prepara o banco antes de iniciar o servidor. Verifique o boot em `http://localhost:3000/up`; a raiz oferece apenas a jornada mínima de cadastro da Fase 0, não os fluxos do MVP. O código-fonte é montado no container, portanto alterações locais são recarregadas sem reconstruir a imagem. Mudanças no `Gemfile` ou no lockfile são conferidas pelo entrypoint.

Com o ambiente em execução:

```bash
docker compose exec web bin/ci
docker compose exec web bin/rails console
docker compose logs -f web
docker compose down
```

Para rodar uma verificação sem iniciar o servidor, o mesmo entrypoint prepara as gems:

```bash
docker compose run --rm web bin/ci
```

`DATABASE_URL` aponta para desenvolvimento e `TEST_DATABASE_URL` para teste. A configuração de teste prioriza explicitamente `TEST_DATABASE_URL`, inclusive em comandos Rails executados com `RAILS_ENV=test`; não substitua essa variável por uma URL de desenvolvimento. Os dados do PostgreSQL 18 ficam em `/var/lib/postgresql/18/docker`, dentro do volume montado em `/var/lib/postgresql`; as gems usam outro volume Docker. `docker compose down` preserva os volumes; use `down -v` somente quando os dados locais puderem ser descartados.

Não reutilize diretamente um volume criado pelo PostgreSQL 17 com a imagem 18. Se os dados locais forem descartáveis, recrie o volume; se precisarem ser preservados, faça migração com `pg_upgrade` ou exportação e restauração antes de trocar a versão. Consulte a [orientação de `PGDATA` da imagem oficial](https://github.com/docker-library/docs/blob/master/postgres/README.md#pgdata).

Não versione o arquivo `.env`: ele é ignorado pelo Git e pode conter apenas credenciais locais.

## Desenvolvimento nativo

Como alternativa ao Docker, instale Ruby na versão indicada em [`.ruby-version`](./.ruby-version), PostgreSQL 18 e as dependências de compilação do `pg`.

```bash
bin/setup --skip-server
bin/dev
```

O banco de desenvolvimento padrão é `quitando_development`. A configuração está em [`config/database.yml`](./config/database.yml); ajuste as credenciais locais ou use `DATABASE_URL` quando necessário.

## Deploy

O [Dockerfile](./Dockerfile) é destinado à imagem de produção e ao Kamal. Injete `RAILS_MASTER_KEY`, `QUITANDO_DATABASE_PASSWORD` e as demais credenciais pelo mecanismo de segredos do ambiente de deploy; não copie `config/master.key` para imagens ou arquivos de exemplo.

O deploy com Kamal usa o GitHub Container Registry e exige `QUITANDO_DEPLOY_HOST`, `QUITANDO_DATABASE_HOST`, `KAMAL_REGISTRY_PASSWORD` e `QUITANDO_DATABASE_PASSWORD` no ambiente que executa o comando. `KAMAL_REGISTRY_USERNAME` é opcional e usa `Luf3r` por padrão.

## Verificação

O comando de integração contínua disponível hoje é:

```bash
bin/ci
```

Ele prepara o ambiente e executa lint, auditorias de dependências e segurança, eager load com Zeitwerk, RSpec e seeds de teste. A suíte já cobre boot, health check, parser monetário, factory, cadastro e processamento Vips; os contratos financeiros pertencem às fases seguintes.

No Docker, execute `docker compose exec web bin/ci` com o ambiente ativo ou `docker compose run --rm web bin/ci` para uma execução avulsa. O GitHub Actions executa o mesmo comando.

## Documentação

- [Contexto do projeto](./PROJECT.md)
- [Especificação do produto](./docs/02-projeto-quitando.md)
- [Domínio, ledger e arquitetura](./docs/03-quitando-domain-architecture.md)
- [UX e fluxos de interação](./docs/04-quitando-ux-ui.md)
- [Roadmap de implementação e estratégia de specs](./docs/05-quitando-roadmap-implementacao.md)
- [Decisões consolidadas](./docs/07-quitando-decisoes-consolidadas.md)
- [Índice completo da documentação](./docs/00-index.md)
- [Kanban de execução no GitHub Project](https://github.com/users/Luf3r/projects/2)
- [Licença Apache 2.0](./LICENSE)

Para contribuir ou alterar o código, leia primeiro as [instruções operacionais](./AGENTS.md). Elas definem a ordem de leitura, os invariantes financeiros e as verificações exigidas em cada fase.
