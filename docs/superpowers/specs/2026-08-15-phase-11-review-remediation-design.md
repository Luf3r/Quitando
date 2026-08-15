# Remediação da revisão da Fase 11 — Desenho

## Objetivo

Corrigir os oito achados da revisão sem mudar domínio financeiro, schema, estados, permissões de domínio ou o GitHub Project. O ciclo financeiro continua operando por HTML convencional; HTTP continua a fonte de reconciliação.

## Contrato da tarefa

- **Fase e gate:** Fase 11, gate de requests, policies e HTML; a correção substitui a evidência incompleta anterior.
- **Fontes:** `PROJECT.md`, `AGENTS.md`, roadmap §14, domínio §§3, 4, 5, 7 e 10, UX, ADR-0008 e ADR-0014.
- **Principal:** cada jornada HTML navegável deve respeitar escopo Pundit, UUID v7 canônico antes da query sensível, arquivo somente leitura, erros preservados e representação explicável por e-mail.
- **Invariantes:** dinheiro continua em centavos inteiros; serviços continuam a revalidar autorização, locks, versão e idempotência; sugestões não entram no histórico; grupo arquivado só permite restauração.
- **Falhas:** ID estruturalmente inválido e recurso fora do scope retornam 404; autorização de papel retorna 403; parâmetro/transição/grupo arquivado retorna 422; conflito de versão ou idempotência retorna 409 com formulário e estado atual.
- **Fora do escopo:** Turbo, Action Cable, grafo, schema, novas permissões, pagamentos arbitrários e alterações financeiras.
- **Contratos afetados:** HTTP, autorização, UI, forms, queries de leitura, documentação de estado e testes. Impacto documental: comportamento HTTP/UI; o Project permanece deliberadamente inalterado até o novo gate.
- **Fallbacks:** nenhum fallback autorizado. Erros inesperados e ledger desequilibrado continuam visíveis.

## Decisões de desenho

### Fronteira de identificadores

`CanonicalUuidV7RouteConstraint` receberá os nomes dos parâmetros que precisa validar e será aplicada a todas as rotas de grupo e recursos aninhados. A rota não será reconhecida quando qualquer ID for ausente, maiúsculo, de outra versão ou com variante inválida. Assim nenhuma action consulta `groups`, `expenses`, `payments`, `memberships` ou convites para esses casos.

### Estado de formulário e erros

As views receberão um objeto de formulário já submetido, inclusive o tipo de split, participantes, shares, data, pagador e idempotency key. No conflito de pagamento, o estado submetido fica separado do snapshot atualizado: a versão exibida é a atual, mas a chave e o texto monetário original permanecem no formulário correspondente. Os campos inválidos continuam visíveis em 422/409.

### UI operacional

A navegação autenticada expõe Grupos e Convites. A lista de grupos inclui a inbox antes da lista operacional. O histórico liga para detalhes e identifica fatos anulados/substituídos; saldos e plano usam e-mails, não UUIDs. O owner recebe formulário textual para reordenar memberships. Despesas criadas por terceiro recebem destaque textual contextual no feed.

### Grupo arquivado e convites

Views de grupo/despesa/pagamento suprimem todas as mutações em grupo arquivado, exceto restauração por owner. O inbox expira somente convites no scope do usuário; o dashboard do owner filtra pendências vencidas para não as apresentar como ações disponíveis. Razões de bloqueio são renderizadas como mensagens de formulário, não respostas genéricas sem contexto.

## Estratégia de teste

Cada fatia começa com uma request/system spec vermelha observando o contrato real. Cobrir:

1. IDs UUID v7 inválidos em cada classe de rota sem SQL contra a tabela sensível.
2. CSRF ativo em uma mutação HTML e isolamento adulterado de grupo/recurso.
3. Arquivado legível, sem controles mutáveis e com endpoints bloqueados.
4. 422/409 preservando todos os campos, especialmente divisão exata e report parcial.
5. Inbox scoped, expiração no limite e dashboard sem convite vencido.
6. Navegação, links de histórico, e-mail no plano/saldos, cadeia de correção, destaque contextual e ordenação HTML.

Depois de cada Green, executar a spec focada e o conjunto relacionado. Ao final, executar `bin/rails tailwindcss:build`, `bin/verify-financial-schema-migrations`, `bin/rubocop`, `bin/ci`, `bin/verify-production-image` e `git diff --check`.
