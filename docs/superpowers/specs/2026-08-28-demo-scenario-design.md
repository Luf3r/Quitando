# Extensão da Fase 13: cenário demo compartilhado e reproduzível

## Contrato

Esta extensão reabre a Fase 13 para tornar a demonstração pública explicável, navegável e descartável. Ela absorve o histórico auditável de convites e o cenário demo, deixando a Fase 14 restrita ao hardening operacional, observabilidade e deploy.

Com `QUITANDO_DEMO_MODE=true`, a aplicação só aceita tráfego depois de `db:prepare` e da instalação idempotente de quatro contas públicas (Ana, Bruno, Carla e Diego) e de um cenário canônico completo. A senha pública é configurada por `QUITANDO_DEMO_PASSWORD`. Dados do ambiente demo são descartáveis: um reset transacional integral ocorre a cada seis horas e sessões anteriores retornam ao login. Dados reais exigem banco e deploy separados com `QUITANDO_DEMO_MODE=false`.

Impacto documental: escopo, fase, gate, comportamento e arquitetura operacional. As fórmulas, centavos inteiros, ledger, append-only, locks financeiros, idempotência, autorização e broadcasts pós-commit permanecem inalterados.

## Histórico de convites

`GroupInvitationPolicy::Scope` passa a incluir todos os convites recebidos pelo usuário; controllers filtram explicitamente pendentes e terminais. `/invitations?page=N` mostra seções Pendentes e Encerrados; somente pendentes exibem ações. Um owner ativo vê em Configurações o histórico dos convites enviados. Entradas mostram grupo, contraparte, estado localizado e timestamp terminal. Os históricos usam 25 itens por página, em ordem decrescente de timestamp terminal e ID; página malformada retorna `422` antes da consulta. O histórico enviado permanece restrito ao owner ativo.

## Cenário canônico

`users.demo_account` é `NOT NULL DEFAULT false`; `demo_scenarios` registra `key`, `version`, `installed_at` e `last_reset_at`, com chave única. `DemoScenario::Config`, `Installer`, `Resetter` e `DemoScenarioResetJob` são as interfaces públicas. Instalador e resetter compartilham advisory lock PostgreSQL; o reset usa `lock_timeout` de 10 segundos, `statement_timeout` de 60 segundos e até cinco novas tentativas, uma por minuto.

O instalador usa exclusivamente os comandos reais de domínio. O cenário cobre: divisão exata, residual determinístico, creator distinto de pagador, revisão, correção imutável, os estados de pagamento, os estados de convite, owner/member ativo/inativo e grupos `empty`, `open`, `awaiting_confirmation`, `settled` e arquivado. Datas são relativas ao reset; identificadores não são contrato público.

Email, senha e recuperação de senha não podem alterar credenciais de `demo_account`; a recuperação não revela se a conta existe. Login e banner global exibem os quatro emails, a senha pública e o próximo reset. Um reset manual requer `CONFIRM_DEMO_RESET=quitando-demo-only` e `QUITANDO_DEMO_DATABASE_NAME` deve coincidir exatamente com o banco atual antes de qualquer `TRUNCATE`.

## Operação e falhas

Instalação e reset são transacionais. Falha parcial preserva o cenário anterior e é observável por evento operacional de início, sucesso ou falha, sem descrições financeiras. O reset descobre dinamicamente as tabelas da base primária e trunca apenas tabelas que não sejam `schema_migrations` nem `ar_internal_metadata`; o lock e todas as escritas pertencem à mesma transação. `Solid Queue` agenda o job somente em production demo.

Não há fallback que simule instalação, reset ou processamento de imagem. Banco não autorizado, modo demo desativado, confirmação ausente, timeout ou falha de seed são erros explícitos. O caminho principal continua obrigatório quando o job, seed ou reset manual são usados.

## Gate adicional da Fase 13

`bin/verify-demo-scenario` usa PostgreSQL temporário validado e demonstra: instalação inicial, instalação idempotente, snapshot canônico, mutação, reset real, comparação do snapshot, rollback integral, rejeição de banco não autorizado e cleanup exato. O gate também cobre autenticação das quatro contas, proteção de suas credenciais, histórico de convites autorizado e paginado, banner de reset, execução concorrente sem duplicação e ausência de estado parcial durante reset.
