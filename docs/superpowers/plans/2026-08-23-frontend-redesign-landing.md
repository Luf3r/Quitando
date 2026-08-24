# Plano de implementação da Fase 13 reaberta

**Spec:** `docs/superpowers/specs/2026-08-23-frontend-redesign-landing-design.md`

## Restrições globais

- Preservar fórmulas, dinheiro, ledger, autorização financeira, locks, idempotência, transições e broadcasts pós-commit.
- Executar Red, Green e Refactor por fatia de comportamento e manter evidência dos comandos.
- Manter HTML funcional sem JavaScript e provar separadamente as melhorias progressivas.
- Não transformar erro, integração ausente ou dependência quebrada em sucesso.
- Não avançar o gate ou o Project sem evidência fresca do diff final.
- Usar Outfit self-hosted, tokens semânticos e os dials `6 / 4 / 4` da spec.

## Tarefa 1: 13.7, gate e fundação visual

Sincronizar produto, UX, roadmap, decisões, `PROJECT.md`, README e relatório de verificação. Reabrir #18, acrescentar 13.7 a 13.14, mover 13.7 para `In progress` e Fase 14 para `Backlog`. Implementar tokens, Outfit, tema antes da pintura, seletor Sistema/Claro/Escuro, foco, progresso Turbo, estados ocupados e componentes de botão, campo, erro, alerta, badge, empty state, page header e navegação. Remover `<main>` aninhados. Adicionar spec contra em dash e en dash visíveis. Corrigir o isolamento Action Cable já reproduzido na sequência de specs da Fase 13.

## Tarefa 2: 13.8, landing, autenticação e conta

Construir landing pública em `/`, CTAs condicionais, seções e SEO previstos na spec. Gerar views Devise em português. Adicionar `/account` com atualização de e-mail e senha mediante senha atual, sem exclusão. Cobrir visitante, autenticado, ordem, metadata e formulários.

## Tarefa 3: 13.9, shell, grupos e convites

Criar header responsivo, contagem real de convites e cards por `GroupListQuery`, sem simplificador. Colocar convites recebidos antes dos grupos, com aceitar e recusar. Cobrir estados vazios, estados financeiros, arquivamento e ausência de `DebtSimplifier`.

## Tarefa 4: 13.10, Resumo e Plano

Adicionar subnavegação e rotas. Criar `GroupOverviewQuery` leve para Resumo e preservar `GroupDashboardQuery` completo e bloqueado para Plano. Renderizar estados, saldos, pendências, sugestão, transferências recentes e atividade no Resumo; pendências, plano, métricas, tabelas, grafo, explicação e trace no Plano. Provar stream/reload e lock.

## Tarefa 5: 13.11, despesas e correções

Criar `ExpenseSplitPreview`, endpoints de preview e formulário unificado com revisão obrigatória. Compartilhar o padrão com correção, preservar versão/idempotência/motivo e manter erros focáveis e conflitos seguros. Cobrir divisão igual, residual, exata, inválidos, ausência de persistência e concorrência.

## Tarefa 6: 13.12, histórico e detalhes

Reformular `GroupHistoryQuery` como página de 25 fatos com `UNION ALL`, ordenação total e carga em lote. Adicionar rota e view de histórico, auditoria completa nos detalhes, confirmação terminal intencional e cancelamento com motivo. Cobrir paginação, página malformada, atores, timestamps, estados e motivos.

## Tarefa 7: 13.13, configurações e memberships

Consolidar nome, convites, memberships, ordem, ownership, saída, arquivamento e restauração. Autorizar a página para todos os membros ativos, manter policies por ação e mostrar bloqueios com motivos derivados das regras existentes. Adicionar confirmações acessíveis e estado somente leitura para grupo arquivado.

## Tarefa 8: 13.14, ativos e gate final

Gerar a fotografia com ImageGen, persistir original e derivados WebP/OG no projeto. Produzir cenário Ana, Bruno e Carla e capturar screenshots reais claro/escuro. Redesenhar erros 400, 404, 422 e 500. Executar o pre-flight integral, specs focadas e relacionadas, suíte, build Tailwind, `bin/ci`, imagem de produção, `git diff --check` e Lighthouse mobile. Reconciliar documentação, #18 e Project. Somente então marcar 13.14 e #18 como `Done` e promover Fase 14 a `Ready`.

## Gate final

```bash
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec
docker compose run --rm web bin/rails tailwindcss:build
docker compose run --rm web bin/ci
docker compose run --rm web bin/verify-production-image
git diff --check
```
