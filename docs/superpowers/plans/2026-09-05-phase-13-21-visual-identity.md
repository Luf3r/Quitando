# Fase 13.21 - Refinamento visual e identidade por nome

## Contexto e contrato global

Esta execução amplia a #144 com o feedback de aceitação. O trabalho acontece na Fase 13.21 e mantém o gate da Fase 13 em aberto até nova aceitação humana. A dependência #140 está concluída; a Fase 14 permanece posterior.

Fontes normativas: `PROJECT.md`, `AGENTS.md`, `docs/00-index.md`, Fase 13 de `docs/05-quitando-roadmap-implementacao.md`, seções 1, 4, 5, 6, 8, 10, 11, 12, 13, 15 e 16 de `docs/03-quitando-domain-architecture.md`, `docs/02-projeto-quitando.md`, `docs/04-quitando-ux-ui.md`, `docs/01-quitando-problema-casos-de-uso.md`, `docs/07-quitando-decisoes-consolidadas.md`, ADR-0012 e issue #144.

Impacto documental: **comportamento**, **banco** e **escopo/fase/gate**. O ADR-0012 permanece válido.

### Comportamento principal

- Adicionar `users.name` obrigatório, normalizado, limitado a 80 caracteres e protegido por constraint PostgreSQL contra vazio após trim.
- Exigir nome no Cadastro e permitir editá-lo em Conta mediante senha atual.
- Usar nome como identidade principal em contextos financeiros, preservando e-mail somente em autenticação, Conta, credenciais demo, convite e informação secundária de administração/auditoria de membros.
- Reorganizar Resumo, Plano, “Entenda o cálculo” e Histórico conforme o feedback de aceitação, com tipografia consistente e responsividade para conteúdo extremo.
- Trocar contratos internos `participant_emails` por `participant_names`.
- Fornecer ao grafo rótulo curto determinístico e nome completo, usando o nome completo em legenda, `<title>` e tabela.
- Preservar as três tabelas completas sem JavaScript e manter indisponibilidade do grafo como falha visível.

### Invariantes

- Ledger, centavos, fórmulas, autorizações, estados financeiros, URLs, IDs Turbo, locks, idempotência, broadcasts pós-commit e reconciliação HTTP não mudam.
- Sugestões continuam derivadas e nunca são tratadas como pagamentos.
- O snapshot estrutural e financeiro demo v2 permanece `4:6:37:7:18:19:1`.
- `User` permanece o participante financeiro do MVP; não surge `Participant` separado.
- A entrada monetária nunca usa `float`.

### Entradas, fronteiras e falhas

- Nome aceita acentos, não é único e normaliza espaços externos e sequências internas.
- Nome vazio após trim, ausente ou acima de 80 caracteres falha explicitamente.
- A migration reconhece somente as quatro contas demo canônicas para backfill; qualquer outro usuário sem nome aborta explicitamente antes de `NOT NULL`.
- Contas demo recebem Ana, Bruno, Carla e Diego sem alterar e-mail ou senha.
- Conteúdo longo não cria overflow no documento; nomes, descrições, e-mails e URLs quebram com segurança, enquanto valores e ações usam `nowrap` somente quando necessário.

### Fallbacks, recuperação e fora do escopo

- Fallback autorizado: HTML/tabelas continuam operacionais quando JavaScript ou o grafo falham, condição já normativa e visivelmente distinguida; isso não conta como grafo funcional.
- Recuperação de erro: validações de nome e falha de migration permanecem erros visíveis, nunca sucesso degradado.
- Fora do escopo: participantes sem conta, unicidade de nome, notificações, disputas, pagamentos integrados, reversão de confirmado, multi-moeda, filtros avançados, mudança de algoritmo, persistência do plano e alteração de URLs.

## Task 1 - Persistência, autenticação e cenário demo por nome

- Atualizar primeiro as fontes normativas de identidade afetadas sem reescrever o ADR-0012.
- Escrever e observar Red para model e constraint PostgreSQL: presença, normalização, 80 caracteres, acentos, vazio após trim e bypass de validation.
- Criar migration reversível e segura que adiciona `name`, reconcilia somente as quatro contas demo canônicas, recusa qualquer residual sem nome, adiciona constraint e `NOT NULL`.
- Exigir nome no Cadastro, permitir atualização em Conta com senha atual e parametrizar Devise.
- Atualizar factory e instalador demo para Ana, Bruno, Carla e Diego, preservando snapshot e credenciais.
- Cobrir specs focadas de model, banco, requests, system e demo; registrar comandos Red e Green.

## Task 2 - Identidade nas consultas, grafo e superfícies financeiras

- Escrever e observar Red para os contratos `participant_names`, nomes em queries/presenters e e-mail restrito aos contextos normativos.
- Substituir `participant_emails` por `participant_names` em snapshots, presenters, formulários, cards, saldos, despesas, pagamentos, convites e histórico.
- Preservar e-mail somente em autenticação, Conta, credenciais demo, convite e como informação secundária na administração/auditoria de membros.
- Estender o payload do grafo com nome completo e rótulo curto determinístico: primeiro nome e inicial, no máximo 18 grafemas; legenda, `<title>` e tabela usam nome completo.
- Cobrir nomes no limite, acentos, nomes longos e equivalência de tabela/grafo.

## Task 3 - Composição visual, tipografia e responsividade extrema

- Escrever e observar Red para tokens tipográficos, estrutura das telas e ausência de overflow com conteúdo extremo.
- Aplicar tracking: display `-0.025em`, títulos `-0.015em`, marca `-0.02em`, corpo e controles `0`; landing e títulos principais usam `line-height: 1.02`; eyebrow mantém tracking positivo.
- Reorganizar Resumo em painel compacto de estado, oficial, projeção, próxima ação, pendências e participantes.
- Organizar Plano em regiões “Pendências” e “Ainda falta” lado a lado no desktop e empilhadas no mobile; cada transferência separa origem, valor, destino e ação.
- Em “Entenda o cálculo”, apresentar `8 → 6 → 3` como faixa de métricas, seletor segmentado, grafo em largura integral, legenda completa e tabela abaixo.
- Reestruturar Histórico como linhas compactas no desktop e registros rotulados no mobile.
- Implementar padrões responsivos para registros operacionais e tabelas comparativas roláveis, com indicação e região acessível.
- Validar 360, 768 e 1440 px, temas claro/escuro, teclado, movimento reduzido e JavaScript desabilitado.

## Task 4 - Gate integrado, documentação de estado e entrega

- Atualizar specs integradas para cenário extremo, duas páginas de histórico e três camadas do grafo.
- Executar specs focadas, conjuntos relacionados, jornadas demo, `bin/verify-demo-scenario`, suíte completa, Tailwind, `bin/ci`, imagem de produção e `git diff --check`.
- Executar inspeção visual responsiva e acessível nos temas claro e escuro, incluindo JavaScript desabilitado.
- Reconciliar produto, domínio, UX, roadmap, decisões consolidadas, `PROJECT.md`, README, #144 e épico #18 somente com evidência fresca.
- Retornar #144 para `Review`; manter #18 aberto até a nova aceitação humana.
- Consolidar os commits temporários desta execução em um único commit coerente sobre o head inicial `a918253`.

## Rodada de aceitação — Hierarquia de ações e refinamento financeiro

Impacto documental desta rodada: **comportamento de UI** e **escopo/fase/gate**. Banco, domínio, ledger, autorização, estados financeiros, rotas, Turbo e fallback HTTP permanecem inalterados.

- Ação primária coral fica restrita ao submit e à próxima ação dominante; “Ver todos”, “Histórico completo”, “Adicionar despesa”, “Revisar pagamento” e “Acompanhar pagamento” são secundárias compactas; perigo confirma transições terminais.
- `StatusBadgeComponent` aceita `status:` canônico e `label:` opcional, preserva `data-status` e declara tom positivo, atenção, neutro ou negativo com texto, borda, contraste e marcador visual.
- Resumo e Histórico compartilham atividade financeira estruturada; cada item separa tipo, descrição, atores, estado, valor, horário e ação, sem nós de pontuação usados como layout.
- Pagamento e Despesa usam coluna legível, metadados em `dl` e regiões de ação separadas. Cancelamento de pagamento é um `details` fechado por padrão, com motivo obrigatório apenas no painel expandido.
- Configurações estrutura nome, e-mail, papel, estado e convites em campos próprios, mantendo explicações de indisponibilidade ligadas por `aria-describedby` e administração avançada recolhida.
- O gate de sistema percorre Resumo, Histórico, Configurações, Pagamento e Despesa em 360, 768 e 1440 px, claro/escuro, duas páginas de histórico, estados financeiros relevantes, foco visível, ausência de overflow e formulários por HTTP sem JavaScript.

## Matriz de evidência obrigatória

```text
Contrato solicitado: identidade por nome e refinamento visual/responsivo da Fase 13.21.
Comportamento principal: nome obrigatório e usado nas superfícies financeiras; telas reorganizadas sem overflow e com equivalência acessível.
Spec que prova o caminho principal: specs focadas de model/banco/auth/demo, queries/presenters/requests e sistema/grafo/gate.
Fallbacks autorizados: HTML e tabelas quando JavaScript/grafo falham, com degradação visível.
Specs dos fallbacks: jornadas sem JavaScript e falha visível do grafo já existentes, atualizadas para os novos nomes e layouts.
Erros que permanecem visíveis: nome inválido, migration com usuário residual, senha atual inválida, página malformada, conflito financeiro e grafo indisponível.
Evidência de que o fallback não é o caminho padrão: specs do grafo real, tabela equivalente, Action Cable e fluxos HTTP executadas separadamente.
```
