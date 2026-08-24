# Plano de implementação - Fase 13

## Contrato da tarefa

- **Fase e gate:** Fase 13, visualização, explicação e acessibilidade. O gate exige demonstrar o produto visualmente sem criar nova fonte de verdade nem bloquear a operação acessível.
- **Fontes normativas consultadas:** `PROJECT.md`, `AGENTS.md`, `docs/00-index.md`, Fase 13 de `docs/05-quitando-roadmap-implementacao.md`, glossário, invariantes, serviços, limites visuais e contratos de teste de `docs/03-quitando-domain-architecture.md`, `docs/02-projeto-quitando.md`, `docs/04-quitando-ux-ui.md`, `docs/01-quitando-problema-casos-de-uso.md`, `docs/07-quitando-decisoes-consolidadas.md` e ADRs 0002, 0003, 0004, 0008 e 0013.
- **Comportamento observável esperado:** apresentar obrigações históricas, compensação bilateral e plano projetado em tabelas semânticas e em grafo equivalente; manter as ações de quitação na tabela; explicar destinatários contraintuitivos e disponibilizar o trace recolhido; preservar a jornada completa por HTTP sem JavaScript.
- **Invariantes:** dinheiro permanece `Integer`; ledger e saldos não mudam; sugestões e trace são derivados e não persistidos; somente despesas ativas originam obrigações; memberships inativas históricas permanecem representadas; tabela e grafo consomem o mesmo payload; HTTP continua fonte de reconciliação; autorização existente do dashboard permanece a fronteira de acesso; nenhuma leitura altera fatos ou `financial_state_version`.
- **Entradas válidas e fronteiras:** grupo autorizado com zero ou mais memberships, despesas ativas ou anuladas, shares positivas e pagamentos em qualquer estado válido. Agregados podem exceder `bigint` e permanecem `Integer` Ruby. Payload estruturalmente válido é desenhado pelo Stimulus; payload inválido torna o grafo visivelmente indisponível e registra o erro, sem ocultar as tabelas.
- **Falhas esperadas:** erros públicos atuais do `DebtSimplifier` permanecem; inconsistências do ledger continuam visíveis; falha estrutural do grafo não é sucesso do grafo; falha de D3 não pode ser convertida em `no-op` silencioso.
- **Fora do escopo:** migrations, schema, cache ou persistência do plano/trace, novo endpoint, nova autorização, cálculo monetário no cliente, analytics, solver exato, períodos financeiros, modo de acerto direto, multi-moeda e notificações.
- **Contratos afetados:** domínio, serviços, query do dashboard, apresentação HTML, i18n, Stimulus/SVG, Turbo morph, Action Cable somente como disparador de refresh, acessibilidade e deploy/importmap. Banco e autorização não mudam.
- **Impacto documental:** **comportamento**, com clarificações normativas de métricas e trace. Não requer ADR novo.

### Classificação dos comportamentos

- **Comportamento principal:** as três camadas derivadas, o trace e a explicação são produzidos pelo servidor; as tabelas e o grafo representam o mesmo payload; a quitação continua operacional por HTTP e pela tabela; acessibilidade, foco, contraste, `aria-live` e movimento reduzido são verificáveis.
- **Fallbacks autorizados:** nenhum fallback novo. A tabela HTML e o grafo D3/SVG são entregas principais complementares.
- **Recuperação de erro:** payload estruturalmente inválido ou erro de renderização marca o grafo como indisponível, mantém todas as tabelas visíveis e registra o erro. Essa recuperação não satisfaz o comportamento principal do grafo.
- **Implementação parcial:** qualquer subissue isolada entrega somente parte do gate e não permite declarar a fase concluída.
- **Fora do escopo:** itens listados no contrato acima.

### Matriz de evidência

```text
Contrato solicitado: visualização explicativa e acessível do grupo na Fase 13.
Comportamento principal: tabelas HTML e grafo D3/SVG equivalentes, trace determinístico, explicação contextual e quitação por HTTP.
Spec que prova o caminho principal: specs de serviço, query/request e system specs listadas neste plano.
Fallbacks autorizados: nenhum novo.
Specs dos fallbacks: não aplicável.
Erros que permanecem visíveis: erros de domínio/ledger e indisponibilidade estrutural do grafo.
Evidência de que o fallback não é o caminho padrão: system spec com D3/SVG real e specs separadas da recuperação de erro.
```

## Fluxo

```text
despesas ativas
-> ObligationGraphBuilder
-> obrigações agregadas
-> compensação bilateral
-> plano projetado + trace
-> payload único
-> tabelas HTML + grafo D3/SVG
```

## Preparação do Project

- Atualizar o épico #18 para `Size: XL`, adicionar label `domain` e mantê-lo no Milestone F, `Phase: Fase 13`, `Priority: P2`, `Type: Epic`, `Dependency: #17`.
- Mover o épico para `In progress` somente quando a primeira subissue começar.
- Criar as subissues abaixo; inicialmente apenas 13.1 fica em `Ready`:

1. **13.1 - Construir obrigações históricas e compensação bilateral**: `Size M`, `Type Behavior`, labels `domain/ux`, dependência #17.
2. **13.2 - Produzir trace determinístico do DebtSimplifier**: `Size S`, `Type Behavior`, labels `domain/ux`, dependência #17.
3. **13.3 - Compor payload, métricas, tabelas e explicação**: `Size L`, `Type Behavior`, labels `domain/ux`, dependências 13.1 e 13.2.
4. **13.4 - Renderizar grafo determinístico com D3/SVG**: `Size M`, `Type Behavior`, label `ux`, dependência 13.3.
5. **13.5 - Hardening de acessibilidade e integração reativa**: `Size M`, `Type Behavior`, labels `ux/security`, dependência 13.4.
6. **13.6 - Demonstrar o gate e reconciliar documentação**: `Size S`, `Type Infrastructure`, labels `ux/infrastructure`, dependência 13.5.

As relações nativas de bloqueio e o campo `Dependency` permanecem coerentes.

## Implementação

### 1. Contrato normativo

Clarificar nos documentos de domínio e UX que:

- cada share de não pagador contribui para uma obrigação;
- relações no mesmo sentido são agregadas antes da apresentação;
- sentidos opostos são compensados pelo valor líquido;
- métricas iniciais contam relações agregadas, relações compensadas e transferências sugeridas;
- a comparação inicial só é apresentada antes de existir qualquer pagamento no histórico;
- depois de report, confirmação ou cancelamento, os números históricos recebem rótulo explicativo e nunca representam trabalho restante;
- trace é derivado, não persistido e recolhido por padrão.

Não há fallback novo: tabela HTML e grafo são entregas principais complementares. Falha do D3 permanece detectável e não pode ser relatada como grafo funcional.

### 2. `ObligationGraphBuilder`

Adicionar a API:

```ruby
ObligationGraphBuilder.call(group)
# => Result(expense_obligations:, bilateral_obligations:)

Edge = Data.define(:from_user_id, :to_user_id, :amount_cents)
Result = Data.define(:expense_obligations, :bilateral_obligations)
```

- Ler somente despesas ativas do grupo.
- Criar contribuição apenas para share cujo usuário não seja o pagador.
- Agregar valores do mesmo par e sentido.
- Compensar pares opostos e remover resultados zero.
- Ordenar por `from_user_id`, depois `to_user_id`.
- Preservar centavos como `Integer`, inclusive acima de `bigint` agregado.
- Não alterar despesas, shares, versão financeira ou entrada.
- Manter participantes inativos presentes quando fizerem parte do histórico.

### 3. Trace do plano

Preservar `DebtSimplifier#call` retornando o array atual e adicionar:

```ruby
DebtSimplifier#call_with_trace
# => Result(transfers:, trace:)

TraceStep = Data.define(
  :iteration,
  :from_user_id,
  :to_user_id,
  :amount_cents,
  :debtor_balance_before_cents,
  :creditor_balance_before_cents,
  :debtor_residue_cents,
  :creditor_residue_cents
)
```

- `call` e `call_with_trace.transfers` são idênticos.
- O mesmo ciclo do algoritmo produz transferências e trace, sem executar o solver duas vezes.
- O trace registra a seleção do maior devedor/credor e resíduos; a UI explica separadamente o desempate por UUID.
- Validação, determinismo, complexidade, imutabilidade e erros públicos atuais permanecem inalterados.

### 4. Payload e apresentação HTML

Estender o snapshot do dashboard com `settlement_trace` e um payload tipado contendo:

- nós: ID, nome apresentado e posição estável;
- camadas `historical`, `bilateral` e `plan`;
- arestas: origem, destino, centavos e valor já formatado pelo servidor;
- métricas, período, denominador e modo `initial_comparison` ou `historical_only`;
- camada inicial: plano, depois bilateral, depois histórica, escolhendo a primeira não vazia.

A tabela operacional atual passa a ser uma tabela semântica `de / para / valor / ação` construída desse payload. O link `Marcar como enviado` permanece nessa tabela e independente do grafo.

O HTML inicial renderiza as três tabelas. Com JavaScript ativo, controles nativos selecionam uma camada e ocultam apenas as tabelas não selecionadas; sem JavaScript, todas continuam disponíveis.

Adicionar:

- explicação curta contextual quando um destinatário do plano não aparece entre os destinatários históricos agregados daquele devedor;
- texto deixando claro que obrigação histórica explica a origem, enquanto plano líquido usa saldos projetados;
- `<details>` `Como chegamos a este plano?` com os passos do trace;
- mensagens financeiras novas em `pt-BR.yml`, com valores renderizados pelo `MoneyComponent`.

Não criar endpoint, coluna, cache, evento ou autorização nova.

### 5. D3/SVG e acessibilidade

- Fixar D3 pelo importmap e submetê-lo à auditoria existente.
- Criar um controller Stimulus que apenas desenha o payload do servidor.
- Usar layout circular determinístico pela posição da membership, com UUID como desempate.
- Não calcular, arredondar, ordenar ou dimensionar dinheiro no JavaScript; arestas têm largura uniforme e usam o valor formatado pelo servidor.
- Renderizar SVG responsivo com setas e rótulos; diferenças entre camadas usam texto e padrões de linha, nunca somente cor.
- Manter o SVG `aria-hidden="true"` e fora da ordem de foco, pois a tabela contém a alternativa completa.
- Usar controles nativos de camada, operáveis por teclado, associados ao gráfico e à tabela correspondente.
- Atualizar um resumo `aria-live="polite"` somente quando o usuário troca de camada.
- Respeitar `prefers-reduced-motion`: transição curta no modo normal e duração zero no modo reduzido.
- Em erro estrutural de renderização, marcar o grafo como indisponível, deixar as tabelas visíveis e registrar o erro.
- Preservar foco ao abrir, fechar por botão ou `Escape` e retornar ao acionador dos diálogos existentes.
- Manter plano/tabela antes do grafo no DOM móvel e tabela visível ao lado do grafo no desktop.

## Testes e evidências

Aplicar Red -> Green -> Refactor por subissue.

- Serviço de obrigações: share do pagador, share de terceiro, agregação, compensação parcial/total, despesas anuladas, isolamento entre grupos, ordem, inteiros grandes, imutabilidade e ausência de escrita.
- Trace: equivalência com `call`, resíduos, desempates, plano vazio, determinismo, imutabilidade, propriedades existentes e execução isolada de Rails/ActiveRecord.
- Payload/request: tabela e JSON possuem exatamente as mesmas arestas; métricas declaram período e denominador; qualquer pagamento muda a apresentação para histórica; cenário Carla/Diego/Ana mostra explicação contraintuitiva; creator e pagador permanecem distintos.
- Sistema sem JavaScript: jornada `group_settlement_spec` continua concluindo report e confirmação exclusivamente pela tabela.
- Sistema com JavaScript: D3 gera nós/arestas para cada camada, seleção mantém equivalência com a tabela, Turbo morph redesenha após mudança remota e estado vazio não cria SVG enganoso.
- Acessibilidade: teclado nos controles, foco inicial/retorno/Escape do diálogo, `aria-live`, nomes e cabeçalhos de tabela, SVG fora do foco, viewport móvel e movimento reduzido via emulação do navegador.
- Para o foco já funcional, usar controle negativo restrito à spec: bloquear temporariamente o listener de fechamento no DOM, provar que o foco não retorna, recarregar e demonstrar o comportamento real.
- Definir cores do grafo em tokens CSS explícitos e verificar WCAG AA: contraste mínimo 4,5:1 para texto e 3:1 para elementos gráficos/estados de foco; cor nunca será o único sinal.

## Comandos finais

```bash
bundle exec rspec spec/services/obligation_graph_builder_spec.rb
bundle exec rspec spec/services/debt_simplifier_spec.rb spec/services/debt_simplifier_property_spec.rb spec/services/debt_simplifier_isolation_spec.rb
bundle exec rspec spec/queries/group_dashboard_query_spec.rb spec/requests/groups_spec.rb
bundle exec rspec spec/system/group_visualization_spec.rb spec/system/group_settlement_spec.rb spec/system/group_realtime_spec.rb
bin/importmap audit
bundle exec rubocop
bin/ci
bin/verify-production-image
git diff --check
```

Depois das evidências frescas, atualizar #18, subissues, `PROJECT.md`, README e o estado da Fase 13 no roadmap. Somente então mover o épico para `Done` e preparar a Fase 14.

## Premissas e limites

- D3 + SVG e trace recolhido foram escolhidos.
- O grafo fica no dashboard existente e usa a autorização já aplicada ao `GET /groups/:id`.
- HTTP permanece fonte de reconciliação; Action Cable apenas provoca refresh autorizado.
- Sem analytics, solver exato, modo de acerto direto, períodos financeiros, persistência do plano ou cálculo financeiro no cliente.
- A alteração preexistente em `db/structure.sql` pertence ao usuário e permanece intocada; a Fase 13 não requer migration.
