# Conexões Neon para os ambientes real e demo

## Objetivo e estado

Preparar a publicação da Fase 14 com dois apps Fly.io que executam a mesma imagem Quitando ao mesmo tempo. O app real usa exclusivamente o projeto Neon real; o app demo usa exclusivamente o projeto Neon demo. A publicação, os testes remotos e o gate completo da Fase 14 são trabalhos posteriores a esta preparação.

O usuário confirmou dois projetos Neon separados, ambos com PostgreSQL 18, e aprovou manter quatro bancos por projeto. As URLs fornecidas na conversa são segredos e não entram em arquivos versionados, exemplos, logs, specs ou histórico Git.

Fontes: `PROJECT.md` (milestone), `AGENTS.md` (seções 3 a 7, 11 a 14), `docs/05-quitando-roadmap-implementacao.md` (Fase 14), `docs/03-quitando-domain-architecture.md` (isolamento demo) e ADR-0016. A tarefa não altera fórmula, ledger, autorização financeira, estados ou escopo do MVP.

## Topologia

| Deploy | Projeto Neon | Banco principal | Bancos auxiliares | Modo demo |
| --- | --- | --- | --- | --- |
| Real | Real | `Quitando` | `quitando_cache`, `quitando_queue`, `quitando_cable` | `false` |
| Demo | Demo | `Demo` | `demo_cache`, `demo_queue`, `demo_cable` | `true` |

Os bancos auxiliares são criados em cada projeto Neon antes do primeiro release. Seus nomes são exemplos operacionais adotados para este deploy e podem ser trocados antes de provisionar, desde que cada URL aponte ao banco correto. A configuração Rails existente continua com `primary`, `cache`, `queue` e `cable` por app. `DEMO_DATABASE_URL` pertence apenas ao desenvolvimento local, em que um processo atende ambos os hosts; produção usa dois processos/deploys e não usa sharding entre projetos.

Cada deploy recebe quatro URLs de runtime via `DATABASE_URL`, `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL` e `CABLE_DATABASE_URL`, além de quatro URLs diretas de migração via `QUITANDO_DIRECT_DATABASE_URL`, `QUITANDO_DIRECT_CACHE_DATABASE_URL`, `QUITANDO_DIRECT_QUEUE_DATABASE_URL` e `QUITANDO_DIRECT_CABLE_DATABASE_URL`. Em um mesmo deploy, cada par de URL direta e agrupada aponta para o mesmo banco. Os hosts das quatro URLs pertencem somente ao projeto daquele deploy. O pooler não representa outro banco.

## Contrato operacional

O caminho principal é: validar configuração e conectividade dos quatro bancos do ambiente correto; executar `db:prepare` no release com URLs diretas; instalar o cenário somente no app demo; iniciar o app com URLs de runtime; provar por consulta que os quatro bancos estão no projeto esperado e usam PostgreSQL 18. A demonstração preserva a guarda exata `QUITANDO_DEMO_DATABASE_NAME=Demo` antes de seed/reset. A aplicação real nunca recebe a senha do projeto demo, e vice-versa. Cada app usa `SECRET_KEY_BASE` próprio.

Ausência de URL, URL malformada, endpoints cruzados, par direto/agrupado com bancos diferentes, versão PostgreSQL incompatível, falha de conexão ou banco auxiliar ausente são erros visíveis e bloqueiam o release. Nenhum fallback está autorizado. Não criar nem apagar bancos automaticamente durante boot ou release; a criação inicial dos auxiliares é uma ação operacional explícita. Nunca executar reset demo no projeto real.

## Entrega e verificação

1. Documentar a criação dos seis bancos auxiliares e o mapeamento de segredos dos dois apps sem valores reais.
2. Acrescentar verificação pré-release que rejeite erros de topologia antes da primeira migration/seed e que não imprima credenciais.
3. Testar as falhas de configuração com valores fictícios e provar que `db:prepare` não é chamado nessas falhas. Testar o caminho principal com as conexões PostgreSQL reais em um ambiente descartável da mesma arquitetura, quando o runtime estiver disponível.
4. Verificar a configuração e a conectividade dos projetos Neon fornecidos por consultas somente de leitura antes de aplicar migrations. Migrar/provisionar apenas após checagem explícita do destino.
5. Executar a spec focada, o conjunto relacionado, `bin/ci`, imagem de produção e smoke tests quando os runtimes estiverem disponíveis. Registrar separadamente qualquer verificação inviável.

O impacto documental é **clarificação operacional** para o mapeamento de URLs e **comportamento** para a nova rejeição pré-release. README e status do projeto devem refletir apenas capacidades comprovadas. O GitHub Project deve receber as evidências quando a credencial com acesso ao Project estiver disponível. Nenhum deploy público ou gate de fase é declarado concluído por esta tarefa isolada.
