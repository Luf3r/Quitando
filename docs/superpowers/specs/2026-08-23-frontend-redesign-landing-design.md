# Fase 13 reaberta: redesign, landing e experiência completa

## Contrato

A Fase 13 volta a estar em andamento para concluir a experiência visual do Quitando. A última fase integralmente concluída passa a ser a Fase 12. O novo gate exige que uma pessoa conheça o produto pela landing pública e execute todas as jornadas do MVP em uma interface coerente, responsiva e acessível, por HTTP sem JavaScript e com melhorias progressivas quando Turbo, Action Cable e o grafo estiverem disponíveis.

O trabalho preserva integralmente fórmulas, dinheiro em centavos inteiros, ledger, autorização financeira, locks, idempotência, transições e broadcasts pós-commit. Não existe fallback autorizado que substitua landing, Action Cable, processamento real de imagem, previews de servidor ou qualquer jornada principal. Falhas de JavaScript mantêm o HTML operacional e aparecem como degradação, nunca como sucesso equivalente.

Impacto documental: escopo, fase, gate e comportamento. Nenhum ADR é necessário porque as decisões arquiteturais financeiras permanecem inalteradas.

## Direção visual

O Quitando usa uma linguagem editorial calorosa e operacionalmente sóbria para adultos em grupos de confiança. A página pública equilibra aquisição e demonstração de engenharia; a aplicação privilegia clareza, leitura rápida e auditabilidade.

- `DESIGN_VARIANCE: 6`
- `MOTION_INTENSITY: 4`
- `VISUAL_DENSITY: 4`
- Tailwind CSS v4, CSS variables, ViewComponent e Stimulus
- Outfit variável, self-hosted, com `font-display: swap`
- wordmark tipográfico “Quitando”, sem símbolo inventado
- containers com raio de 20 px, controles com 12 px e badges pill
- coral como único acento interativo
- cores financeiras exclusivamente semânticas, sempre acompanhadas por texto

| Token | Claro | Escuro |
|---|---|---|
| Fundo | `#F6F7F9` | `#15171B` |
| Superfície | `#FFFFFF` | `#1D2026` |
| Superfície secundária | `#EEF1F4` | `#262A32` |
| Texto | `#24262B` | `#F3F4F6` |
| Texto secundário | `#626873` | `#B8BEC8` |
| Borda | `#D8DDE5` | `#3A404B` |
| Acento | `#C2413B` | `#FF7A70` |
| Hover | `#A93632` | `#FF938A` |
| Texto no acento | `#FFFFFF` | `#2A0B08` |

O tema aceita `system`, `light` ou `dark`, é persistido em `quitando.theme` e aplicado no `head` antes da primeira pintura. Valor armazenado inválido é removido e volta para `system`.

## Arquitetura de informação

Visitantes chegam a `/`, veem a proposta do produto e seguem para cadastro ou explicação. Usuários autenticados veem a mesma landing com o CTA “Abrir app”. O shell autenticado oferece Grupos, Convites, Conta, Tema e Sair.

Cada grupo possui quatro destinos HTTP:

1. Resumo: posição pessoal, pendências, sugestão acionável e atividade recente.
2. Plano: pendências, plano textual, tabelas, grafo, explicação e trace.
3. Histórico: fatos financeiros paginados e auditáveis.
4. Configurações: nome, convites, memberships, ownership e arquivamento.

O fluxo existente continua acessível por URLs estáveis. As novas rotas são:

- `GET /groups/:id/plan`
- `GET /groups/:id/history?page=N`
- `GET /groups/:id/settings`
- `POST /groups/:group_id/expenses/preview`
- `POST /groups/:group_id/expenses/:expense_id/correction/preview`
- `GET /account`
- `PATCH /account`

## Consultas e snapshots

- `GroupListQuery::Card` reúne grupo, membros, estado, saldo do usuário, pendências e arquivamento sem chamar `DebtSimplifier`.
- `GroupOverviewQuery::Snapshot` compõe um resumo leve, sem grafo ou obrigações históricas.
- `GroupDashboardQuery::Snapshot` permanece como composição completa da página Plano e mantém o lock do grupo durante toda a leitura.
- `GroupHistoryQuery::Page` contém entradas, página, total de páginas e total de fatos, com 25 itens por página. A consulta usa `UNION ALL`, ordena por timestamp e ID e carrega registros em lote.
- `ExpenseSplitPreview::Result` contém valor, tipo e shares em centavos, sem persistência.

Página histórica malformada retorna `422`. Preview inválido retorna `422` no mesmo frame e não grava qualquer fato.

## Landing e conteúdo

O hero usa composição assimétrica com fotografia lifestyle real. O título é “Feche as contas do grupo sem refazer cada dívida.” O texto é “Registre despesas, acompanhe confirmações e veja um plano prático com menos transferências.” Há um CTA primário de cadastro ou app e o CTA secundário “Como funciona”.

As seções seguem esta ordem:

1. ciclo Registre, Entenda, Envie, Confirme;
2. distinção entre saldo oficial, pendência e plano;
3. screenshot real do dashboard;
4. engenharia: centavos inteiros, plano derivado, HTTP e acessibilidade;
5. fronteira de confiança;
6. CTA final.

Não existem pricing, depoimentos, logos de clientes ou métricas inventadas. Metadata, canonical e Open Graph descrevem somente capacidades reais.

## Jornadas e formulários

Login, cadastro e recuperação de senha são apresentados em português. `/account` permite alterar e-mail ou senha mediante senha atual. Exclusão de conta não faz parte do MVP e não aparece na interface.

Criação e correção de despesa usam um formulário único com divisão igual ou exata. O fluxo obrigatório tem entrada editável, preview calculado no servidor, resumo somente leitura e confirmação final. A divisão igual mostra shares e residual determinístico. A divisão exata exige soma idêntica ao total. Correção inclui motivo, versão financeira e idempotency key.

Erros aparecem abaixo do campo e em resumo focável. Conflitos concorrentes preservam somente dados seguros e continuam visíveis como conflito, nunca como sucesso.

## Histórico e detalhes

O histórico mostra 25 fatos por página, com tipo, atores, valor, estado localizado, data e hora, motivo e link. O detalhe de despesa exibe data, shares, creator, pagador, anulação, substituição e revisões descritivas. O detalhe de pagamento exibe estado, origem, destino, reporter, confirmer ou canceller, timestamps e motivo.

Confirmar pagamento reforça que a ação é terminal no MVP e exige intenção explícita. Cancelamento continua exigindo motivo.

## Estados, acessibilidade e responsividade

As telas cobrem carregamento, vazio, erro, sucesso, grupo arquivado e os quatro estados financeiros. O texto nunca depende apenas de cor. Foco global, erros focáveis, `aria-live`, controles nativos, ordem de leitura, viewport móvel e `prefers-reduced-motion` são contratos verificáveis.

O HTML completo funciona em 360, 768 e 1440 px sem JavaScript. Turbo e Action Cable melhoram atualização e diálogo; queda do stream permanece visível e o reload reconcilia. O grafo continua complementar à tabela equivalente.

Strings visíveis não usam em dash ou en dash. O pre-flight de design deve ser executado integralmente nos temas claro e escuro antes do gate.

## Ativos

A fotografia do hero mostra quatro amigos adultos depois de uma refeição compartilhada, em cena editorial natural, luz diurna e detalhes coral, sem texto, logos, dinheiro legível ou estética genérica de banco de imagens. O original gera WebP em 480, 768 e 1024 px e uma imagem Open Graph.

Screenshots reais usam Ana, Bruno e Carla no cenário normativo, em claro e escuro. Páginas 400, 404, 422 e 500 recebem a mesma linguagem visual.

## Gate

O gate é demonstrado somente quando landing, shell e todas as jornadas do MVP atendem os contratos em HTTP sem JavaScript, com melhorias progressivas verificadas, assets reais, responsividade e acessibilidade. Os comandos obrigatórios são os definidos no plano da mesma data, além de Lighthouse mobile na landing e no Resumo autenticado com LCP abaixo de 2,5 s, CLS abaixo de 0,1, INP abaixo de 200 ms e nenhuma falha crítica de acessibilidade.

Depois disso a Fase 14 pode voltar a `Ready`, restrita a observabilidade operacional, rate limit, secrets, backups, produção, cenário de demonstração, Kamal, smoke tests, rollback e deploy real.
