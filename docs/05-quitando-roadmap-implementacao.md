# Quitando — Roadmap de Implementação e Estratégia de Specs

Este documento transforma o roadmap funcional do produto em uma **ordem técnica de implementação**. Ele define dependências, specs prioritárias e critérios de saída por etapa.

O roadmap de produto responde **o que entra em cada release**. Este documento responde **em que ordem construir**, para reduzir retrabalho e validar primeiro as regras de maior risco.

Consulte também o [índice da documentação](./00-index.md). Decisões arquiteturais relacionadas ficam em [`adr/`](./adr/).

## Navegação rápida

- [1. Princípios da implementação](#1-princípios-da-implementação)
- [2. Pirâmide de testes](#2-pirâmide-de-testes)
- [3. Fase 0 — Fundação do projeto](#3-fase-0-fundação-do-projeto)
- [4. Fase 1 — `DebtSimplifier` em Ruby puro](#4-fase-1-debtsimplifier-em-ruby-puro)
- [5. Fase 2 — Schema e entidades financeiras mínimas](#5-fase-2-schema-e-entidades-financeiras-mínimas)
- [6. Fase 3 — Criação de despesas e arredondamento](#6-fase-3-criação-de-despesas-e-arredondamento)
- [7. Fase 4 — Ledger e saldo oficial](#7-fase-4-ledger-e-saldo-oficial)
- [8. Fase 5 — Primeiro plano de quitação](#8-fase-5-primeiro-plano-de-quitação)
- [9. Fase 6 — Saldo projetado](#9-fase-6-saldo-projetado)
- [10. Fase 7 — Workflow de pagamentos](#10-fase-7-workflow-de-pagamentos)
- [11. Fase 8 — Situação financeira derivada do grupo](#11-fase-8-situação-financeira-derivada-do-grupo)
- [12. Fase 9 — Correção imutável de despesas](#12-fase-9-correção-imutável-de-despesas)
- [13. Fase 10 — Grupos, convites e ciclo de memberships](#13-fase-10-grupos-convites-e-ciclo-de-memberships)
- [14. Fase 11 — Requests, policies e HTML funcional](#14-fase-11-requests-policies-e-html-funcional)
- [15. Fase 12 — Turbo Frames, Streams e Action Cable](#15-fase-12-turbo-frames-streams-e-action-cable)
- [16. Fase 13 — Visualização, explicação e acessibilidade](#16-fase-13-visualização-explicação-e-acessibilidade)
- [17. Fase 14 — Hardening, observabilidade e deploy](#17-fase-14-hardening-observabilidade-e-deploy)
- [18. Milestones recomendadas](#18-milestones-recomendadas)
- [19. Primeiros arquivos de spec](#19-primeiros-arquivos-de-spec)
- [20. O que não deve bloquear o início](#20-o-que-não-deve-bloquear-o-início)
- [21. Critério geral de pronto do MVP](#21-critério-geral-de-pronto-do-mvp)
- [22. Objetivos pós-MVP](#22-objetivos-pós-mvp)

---


## 1. Princípios da implementação

### 1.1 Specs acompanham cada etapa

Testes não são a última atividade do MVP. Cada fase termina com seus contratos automatizados verdes antes que a próxima dependência seja introduzida.

A ordem preferencial é:

```text
regra pura
-> persistência e constraints
-> serviço transacional
-> request HTTP
-> autorização
-> Hotwire/real-time
-> apresentação visual
```

### 1.2 Construir por risco, não por tela

Os maiores riscos são:

1. sinais e conservação do ledger;
2. arredondamento e soma das shares;
3. projeção de pagamentos pendentes;
4. idempotência e concorrência;
5. autorização de comandos financeiros;
6. reconciliação entre HTTP e atualizações em tempo real.

Grafo, animações e microinterações ficam depois que esses contratos estiverem estáveis.

### 1.3 HTTP é o primeiro caminho completo

O fluxo deve funcionar com requests e páginas convencionais antes de Action Cable e Turbo Streams. Real-time melhora a experiência, mas não é fonte de verdade. Isso não autoriza usar HTTP como substituto de uma entrega posterior que peça stream ou broadcast: nessa tarefa, o caminho em tempo real continua sendo o comportamento principal e HTTP é apenas reconciliação.

### 1.4 O domínio não depende da interface

`DebtSimplifier` e, quando possível, calculadores de saldo recebem estruturas simples e possuem testes independentes de controllers, Turbo, Active Job e Action Cable.

### 1.5 Pequenas entregas demonstráveis

Cada milestone deve produzir algo executável e verificável, mesmo que ainda sem acabamento visual.

### 1.6 O caminho principal não é substituível

O gate de uma fase exige o comportamento principal que ela declara. Um fallback autorizado pode degradar uma condição específica, mas não substitui silenciosamente o resultado solicitado, não satisfaz o gate sozinho e não transforma falha em sucesso. As specs devem demonstrar o caminho principal e, quando existir, cobrir o fallback separadamente; consulte a política operacional completa em [`AGENTS.md`](../AGENTS.md).

---

## 2. Pirâmide de testes

### 2.1 Specs de domínio e serviços

Cobrem a maior parte das regras:

- algoritmos puros;
- ledger;
- projeção;
- arredondamento;
- comandos transacionais;
- estados;
- autorização de domínio;
- concorrência e idempotência.

Devem ser rápidas e formar a base da suíte.

### 2.2 Model e database specs

Validam:

- foreign keys;
- índices únicos;
- checks de banco;
- enumerações e transições;
- restrições que não podem depender somente de validações Rails.

### 2.3 Request specs

Validam o contrato HTTP:

- autenticação;
- Pundit;
- parâmetros;
- respostas de sucesso e erro;
- versão obsoleta;
- idempotência;
- fallback sem JavaScript.

### 2.4 System specs

Devem ser poucas e focadas em jornadas críticas:

- criar grupo e aceitar convite;
- registrar despesa;
- visualizar saldo e plano;
- reportar e confirmar pagamento;
- chegar a `settled`;
- executar o fluxo sem depender do grafo.

### 2.5 Testes de propriedades

Usados principalmente para:

- `DebtSimplifier`;
- conservação dos saldos;
- projeção de reports válidos;
- arredondamento determinístico.

Não substituem exemplos legíveis; complementam-nos.

---

## 3. Fase 0 — Fundação do projeto

### 3.1 Objetivo

Criar uma base reproduzível para desenvolver e executar a suíte.

### 3.2 Implementar

- aplicação Rails 8.x com PostgreSQL 18;
- RSpec;
- FactoryBot ou factories equivalentes;
- autenticação mínima com Devise;
- Pundit instalado, ainda sem todas as policies;
- lint e formatação;
- CI remoto executando o mesmo contrato de `bin/ci`, sem divergências silenciosas de comandos ou severidade;
- configuração de Solid Queue e Solid Cable, sem uso funcional obrigatório;
- helpers para converter texto monetário em centavos sem `float`.

As dependências exclusivas de teste não entram na imagem de produção: o build de produção exclui os grupos Bundler `development:test`.

### 3.3 Specs e verificações

- boot da aplicação;
- health check HTTP;
- conexão de teste com PostgreSQL 18;
- autenticação básica;
- parser monetário para valores válidos e inválidos, incluindo `12`, `1.234,56`, texto vazio, zero, sinal, ponto decimal e precisão acima de centavos;
- transformação observável com o processador de imagens configurado; se `:vips` estiver selecionado, a spec carrega `image_processing/vips` e processa uma imagem de teste com `ruby-vips`;
- pelo menos um exemplo RSpec real para cada contrato acima, incluindo uma jornada de autenticação quando Devise estiver configurado;
- a suíte executa ao menos uma system spec real quando a jornada de autenticação for introduzida; um job separado só pode existir quando possuir exemplos descobertos; zero exemplos não é evidência de cobertura;
- CI falha quando uma spec falha e executa `bin/ci` como fonte única do contrato, incluindo seeds e a mesma severidade das auditorias locais.

### 3.4 Gate de saída

```text
bin/ci
```

executa localmente e no CI com banco limpo e resultado reproduzível, incluindo boot, health check, PostgreSQL, autenticação, parser monetário, factories, processador de imagens configurado e exemplos reais. O gate não é atendido por uma suíte vazia, por job de system spec sem exemplos, por mock que substitua o contrato da integração ou por fallback que esconda a ausência do comportamento principal.

---

## 4. Fase 1 — `DebtSimplifier` em Ruby puro

### 4.1 Objetivo

Validar o núcleo algorítmico sem banco ou interface.

### 4.2 Implementar

```text
app/services/debt_simplifier.rb
```

Entrada:

```ruby
{ user_id => balance_cents }
```

Saída:

```ruby
[
  Transfer.new(from_user_id:, to_user_id:, amount_cents:)
]
```

### 4.3 Specs mínimas

```text
spec/services/debt_simplifier_spec.rb
```

Casos obrigatórios:

- mapa vazio retorna nenhuma transferência;
- saldos zero são ignorados;
- um devedor e um credor;
- múltiplos devedores e credores;
- entrada cuja soma não é zero é rejeitada;
- todas as transferências têm valor positivo;
- origem e destino são diferentes;
- aplicar a saída zera os saldos;
- valor total é conservado;
- entrada não é modificada;
- a mesma entrada gera a mesma saída;
- empates seguem a regra estável;
- quantidade de transferências é no máximo `m - 1`.

### 4.4 Testes de propriedade

Para mapas aleatórios com soma zero, verificar conservação, quitação, determinismo e validade das transferências.

### 4.5 Gate de saída

O serviço atende a todos os invariantes sem carregar Rails ou ActiveRecord.

---

## 5. Fase 2 — Schema e entidades financeiras mínimas

### 5.1 Objetivo

Criar o modelo persistente necessário ao ledger.

### 5.2 Implementar

- `User`;
- `Group`;
- `Membership`;
- `Expense`;
- `ExpenseShare`;
- `Payment`;
- `financial_state_version` no grupo;
- enums ou estados definidos na documentação de domínio.

`GroupInvitation` pode ser migrado nesta fase ou na fase específica de memberships, mas não precisa bloquear o ledger.

### 5.3 Constraints prioritárias

- `unique(group_id, user_id)` em memberships;
- `unique(expense_id, user_id)` em shares;
- `amount_cents > 0`;
- `amount_owed_cents > 0`;
- `from_user_id <> to_user_id`;
- `idempotency_key` única;
- foreign keys obrigatórias;
- dinheiro em `bigint`;
- estados válidos no banco quando viável.

### 5.4 Specs

```text
spec/models/group_spec.rb
spec/models/membership_spec.rb
spec/models/expense_spec.rb
spec/models/expense_share_spec.rb
spec/models/payment_spec.rb
```

Além das validations, incluir testes que provoquem violações diretamente no banco para as constraints críticas.

### 5.5 Gate de saída

O banco recusa os estados estruturalmente inválidos mesmo quando validações Rails são contornadas.

---

## 6. Fase 3 — Criação de despesas e arredondamento

### 6.1 Objetivo

Persistir uma despesa completa de forma atômica e reproduzível.

### 6.2 Implementar

- `ExpenseCreator`;
- divisão igual;
- divisão por valor exato;
- reconciliador de centavos residuais;
- incremento atômico de `financial_state_version`;
- auditoria de `created_by_user_id`.

### 6.3 Specs

```text
spec/services/expense_creator_spec.rb
spec/services/equal_split_calculator_spec.rb
```

Casos:

- cria despesa e shares na mesma transação;
- divisão igual exata;
- divisão com centavos residuais;
- prioridade determinística do pagador e ordem do membership;
- divisão por valores exatos;
- soma divergente rejeita tudo;
- participante inativo é rejeitado;
- usuário de outro grupo é rejeitado;
- pagador pode ser outro membro ativo;
- `created_by_user_id` e `paid_by_user_id` permanecem distintos quando o registro é feito por terceiro;
- o destaque contextual ao pagador só aparece depois do commit e não altera o estado financeiro da despesa;
- despesa precisa produzir ao menos uma obrigação para não pagador;
- falha em uma share executa rollback integral;
- criação concorrente é serializada sem falhar apenas por versão obsoleta.

### 6.4 Gate de saída

É possível criar despesas válidas por serviço e provar que nenhuma despesa parcial fica persistida.

---

## 7. Fase 4 — Ledger e saldo oficial

### 7.1 Objetivo

Calcular corretamente quanto cada participante deve receber ou pagar.

### 7.2 Implementar

```text
app/services/group_balance_calculator.rb
```

### 7.3 Specs

```text
spec/services/group_balance_calculator_spec.rb
```

Exemplo-base:

```text
Despesa de 9000
Ana pagou
Shares: Ana 3000, Bruno 3000, Carla 3000

Ana   +6000
Bruno -3000
Carla -3000
```

Depois de Bruno pagar 2000 para Ana e o pagamento ser confirmado:

```text
Ana   +4000
Bruno -1000
Carla -3000
```

Casos adicionais:

- soma dos saldos é zero;
- múltiplas despesas e pagadores;
- participantes fora de determinada despesa;
- despesas anuladas são ignoradas;
- somente pagamentos `confirmed` entram no oficial;
- `reported` e `cancelled` não alteram o oficial;
- memberships inativos com histórico continuam no cálculo;
- coleções vazias retornam estado coerente.

### 7.4 Gate de saída

Para qualquer fixture válida, o saldo oficial é reproduzível e sua soma é zero.

---

## 8. Fase 5 — Primeiro plano de quitação

### 8.1 Objetivo

Integrar saldo oficial e algoritmo antes de introduzir pagamentos pendentes.

### 8.2 Fluxo

```text
GroupBalanceCalculator
-> DebtSimplifier
-> lista textual de transferências
```

### 8.3 Specs

- o plano zera o saldo oficial;
- um grupo já equilibrado retorna plano vazio;
- o plano é determinístico;
- um cenário em que a obrigação histórica aponta para Diego e o plano líquido aponta para Ana permanece contabilmente correto;
- os IDs pertencem ao grupo;
- lista textual possui os mesmos dados do resultado do serviço.

### 8.4 Milestone demonstrável

Por console, endpoint simples ou página HTML sem real-time:

1. criar despesas;
2. visualizar saldos;
3. receber instruções “quem paga quem”.

### 8.5 Gate de saída

O núcleo do produto funciona por HTTP ou console sem pagamentos pendentes, grafo ou Turbo Streams.

---

## 9. Fase 6 — Saldo projetado

### 9.1 Objetivo

Reservar pagamentos reportados para que não sejam sugeridos novamente.

### 9.2 Implementar

```text
app/services/projected_balance_calculator.rb
```

### 9.3 Specs

```text
spec/services/projected_balance_calculator_spec.rb
```

Casos:

- sender caminha em direção a zero;
- receiver caminha em direção a zero;
- soma projetada permanece zero;
- saldo oficial de entrada não é modificado;
- múltiplos reports são aplicados;
- report cancelado não entra na projeção;
- report confirmado deixa de entrar na projeção e passa ao oficial;
- cancelar um report restaura a projeção anterior;
- reports válidos não devem ultrapassar os limites definidos pelo plano no momento da criação.

### 9.4 Integração

```text
saldo oficial
-> aplicar reported
-> saldo projetado
-> DebtSimplifier
-> plano restante
```

### 9.5 Gate de saída

Um valor reportado aparece como pendência e desaparece do plano restante sem alterar o saldo oficial.

---

## 10. Fase 7 — Workflow de pagamentos

### 10.1 Objetivo

Implementar comandos financeiros seguros e concorrentes.

### 10.2 Implementar

- `PaymentReporter`;
- `PaymentConfirmer`;
- `PaymentCanceller`;
- `request_fingerprint`;
- idempotência;
- lock/serialização por grupo;
- checagem de `expected_financial_state_version` no report;
- transições condicionais para confirmar e cancelar.

### 10.3 Specs do reporter

```text
spec/services/payment_reporter_spec.rb
```

- somente a origem pode reportar;
- aceita uma sugestão atual;
- aceita pagamento parcial;
- rejeita zero, negativo e valor acima da sugestão;
- rejeita par que não existe no plano atual;
- versão obsoleta não grava;
- mesma chave e mesmo payload retorna o resultado anterior;
- mesma chave e payload diferente retorna conflito;
- dois reports concorrentes não reservam o mesmo valor;
- report não altera saldo oficial;
- report incrementa a versão financeira uma vez.

### 10.4 Specs do confirmer

```text
spec/services/payment_confirmer_spec.rb
```

- somente o recebedor confirma;
- apenas `reported` pode ser confirmado;
- altera o saldo oficial exatamente uma vez;
- remove o efeito pendente da projeção;
- duas confirmações simultâneas produzem uma transição;
- `confirmed` é terminal no MVP.

### 10.5 Specs do canceller

```text
spec/services/payment_canceller_spec.rb
```

- pagador ou recebedor pode cancelar;
- terceiro não pode cancelar;
- exige motivo;
- restaura o valor ao plano projetado;
- cancelamento concorrente ocorre uma vez;
- `cancelled` é terminal.

### 10.6 Gate de saída

O fluxo completo abaixo passa em service specs, inclusive com exemplos concorrentes:

```text
despesa
-> saldo oficial
-> plano
-> report
-> projeção
-> confirmação
-> novo saldo oficial
```

---

## 11. Fase 8 — Situação financeira derivada do grupo

### 11.1 Objetivo

Derivar o estado apresentado pela interface sem persistir uma segunda fonte de verdade.

### 11.2 Implementar

```text
app/services/group_financial_status_resolver.rb
```

### 11.3 Specs

```text
spec/services/group_financial_status_resolver_spec.rb
```

- `empty` sem atividade financeira;
- `open` com saldo oficial não zero e sem report;
- `awaiting_confirmation` com ao menos um report;
- `awaiting_confirmation` pode coexistir com plano restante;
- `settled` exige atividade, saldos oficiais zero e nenhum report;
- grupo vazio nunca é `settled`;
- arquivamento não substitui a situação financeira.

### 11.4 Gate de saída

Todos os estados do dashboard podem ser derivados de fatos persistidos, sem coluna de status financeiro mutável.

---

## 12. Fase 9 — Correção imutável de despesas

### 12.1 Objetivo

Corrigir fatos financeiros sem sobrescrever histórico.

### 12.2 Implementar

- `ExpenseCorrector`;
- anulação da original;
- criação da substituta na mesma transação;
- `void_reason`, ator e `replaces_expense_id`;
- edição separada para campos puramente descritivos;
- versionamento de mudanças financeiras.

### 12.3 Specs

```text
spec/services/expense_corrector_spec.rb
```

- valor, pagador e shares originais não são sobrescritos;
- original é marcada como anulada;
- substituta é válida e vinculada;
- operação é atômica;
- motivo e ator são obrigatórios;
- pagamentos existentes permanecem intactos;
- saldo oficial, projeção e plano são recalculados;
- correção concorrente com report respeita lock e versão;
- descrição pode ser alterada sem modificar versão financeira quando não afeta o ledger.

### 12.4 Gate de saída

O histórico explica integralmente como o estado atual foi obtido.

---

## 13. Fase 10 — Grupos, convites e ciclo de memberships

### 13.1 Objetivo

Completar a formação e administração do grupo sem fragilizar o domínio financeiro.

### 13.2 Implementar

- `GroupCreator`;
- owner inicial;
- `GroupInvitation`;
- aceitar, recusar, revogar e expirar;
- reativação do mesmo membership;
- inativação segura;
- transferência de owner;
- arquivamento e restauração.

### 13.3 Specs

```text
spec/services/group_creator_spec.rb
spec/services/group_invitation_creator_spec.rb
spec/services/group_invitation_accepter_spec.rb
spec/services/membership_reactivator_spec.rb
spec/services/membership_deactivator_spec.rb
spec/services/group_archiver_spec.rb
```

Casos:

- grupo e owner inicial são criados juntos;
- convite duplicado é impedido;
- convite não concede acesso antes da aceitação;
- somente o convidado aceita ou recusa;
- somente owner cria ou revoga;
- expiração é idempotente;
- aceite cria ou reativa um único membership;
- membro com saldo ou pendência não sai;
- último owner não sai sem transferir propriedade;
- grupo aberto, com pendência ou convite aberto não é arquivado;
- restaurar não altera ledger nem moeda.

### 13.4 Gate de saída

Um grupo consegue formar sua lista de membros, operar e encerrar o ciclo de acesso sem duplicar histórico.

---

## 14. Fase 11 — Requests, policies e HTML funcional

### 14.1 Objetivo

Expor o domínio por HTTP antes de real-time e acabamento visual.

### 14.2 Implementar

- rotas e controllers;
- Pundit policies;
- páginas HTML essenciais;
- formulários convencionais;
- mensagens de validação;
- resposta específica para versão obsoleta;
- history/feed básico.

### 14.3 Request specs

```text
spec/requests/groups_spec.rb
spec/requests/group_invitations_spec.rb
spec/requests/expenses_spec.rb
spec/requests/payments_spec.rb
spec/requests/memberships_spec.rb
```

Validar:

- autenticação;
- isolamento entre grupos;
- permissions por papel e relação;
- parâmetros inválidos;
- transições não permitidas;
- conflito de idempotência;
- resposta de versão obsoleta;
- redirects e status HTTP;
- reload sempre mostra o estado correto.

### 14.4 System spec principal

```text
spec/system/group_settlement_spec.rb
```

Jornada:

1. owner cria grupo;
2. usuário aceita convite;
3. membros registram despesas;
4. sistema mostra saldo e plano, incluindo explicação quando o destinatário não coincide com o pagador lembrado;
5. devedor reporta pagamento;
6. recebedor confirma;
7. grupo chega a `settled`.

### 14.5 Gate de saída

O MVP financeiro funciona de ponta a ponta com HTML e sem depender de WebSocket ou grafo.

---

## 15. Fase 12 — Turbo Frames, Streams e Action Cable

### 15.1 Objetivo

Adicionar reatividade sem alterar as regras de domínio.

### 15.2 Implementar

- modais/bottom sheets com Turbo Frames;
- respostas Turbo Stream;
- broadcasts depois do commit;
- subscriptions autorizadas;
- reconciliação por HTTP após reload ou reconexão;
- componentes atualizados de forma consistente.

### 15.3 Specs

- broadcast não ocorre antes do commit;
- rollback não emite sucesso;
- usuário não assina stream de outro grupo;
- falha de broadcast não desfaz comando persistido;
- resposta HTML convencional continua funcional;
- stream e reload exibem o mesmo estado lógico;
- versão obsoleta atualiza contexto sem apagar formulário quando seguro;
- despesa registrada por terceiro aparece com creator e pagador distintos por HTTP e, quando conectado, por stream somente depois do commit.

### 15.4 Gate de saída

Dois navegadores podem observar mudanças em tempo real, mas o sistema continua correto quando Action Cable está indisponível.

---

## 16. Fase 13 — Visualização, explicação e acessibilidade

### 16.1 Objetivo

Adicionar o diferencial demonstrativo sem transformar o grafo em requisito operacional.

### 16.2 Implementar

- `ObligationGraphBuilder`;
- obrigações de despesas;
- compensação bilateral;
- plano simplificado;
- tabela textual equivalente;
- SVG/D3;
- trace opcional do algoritmo;
- estados vazios, foco, `aria-live` e `prefers-reduced-motion`.

### 16.3 Specs

- obrigação criada somente para share de não pagador;
- agregação do mesmo par;
- compensação de sentidos opostos;
- tabela e grafo usam o mesmo payload;
- executar pagamento não depende do grafo;
- métricas declaram denominador e período;
- explicação curta distingue obrigação histórica de plano líquido em cenário contraintuitivo;
- detalhe de despesa distingue `registrado por` de `pago por`;
- comparação histórica não é apresentada como trabalho restante após reports;
- navegação por teclado e foco dos modais funcionam.

### 16.4 Gate de saída

O produto pode ser demonstrado visualmente sem introduzir nova fonte de verdade ou bloquear acessibilidade.

---

## 17. Fase 14 — Hardening, observabilidade e deploy

### 17.1 Objetivo

Preparar o MVP para demonstração pública e piloto real.

### 17.2 Implementar

- logs estruturados sem dados financeiros desnecessários;
- monitoramento de jobs, broadcasts e invariantes;
- seeds ou cenário de demonstração;
- proteção de rate limit onde aplicável;
- backups e configuração de produção;
- deploy com Kamal;
- smoke tests;
- revisão de índices e queries;
- documentação do README e GIF/demo;
- roteiro de teste com usuário para destinatário contraintuitivo e despesa registrada por terceiro.

### 17.3 Verificações

- falha de soma zero gera erro observável;
- erros não vazam descrições sensíveis;
- jobs e broadcasts falhos não corrompem comandos já confirmados;
- página inicial e fluxo principal funcionam após deploy limpo;
- o cenário demo pode ser recriado de forma determinística.

### 17.4 Gate de saída

Uma pessoa externa consegue usar o fluxo principal em ambiente publicado e compreender saldo, pendência, plano e encerramento.

---

## 18. Milestones recomendadas

### 18.1 Milestone A — Núcleo matemático

Inclui fases 0 a 4.

Entrega:

```text
despesas persistidas
-> saldo oficial correto
-> algoritmo isolado testado
```

### 18.2 Milestone B — Primeiro plano utilizável

Inclui fase 5.

Entrega:

```text
saldo oficial
-> lista de transferências sugeridas
```

### 18.3 Milestone C — Ciclo financeiro completo

Inclui fases 6 a 9.

Entrega:

```text
plano
-> report
-> saldo projetado
-> confirmação/cancelamento
-> saldo oficial atualizado
-> correção auditável
```

### 18.4 Milestone D — Produto HTTP completo

Inclui fases 10 e 11.

Entrega:

```text
grupo e convites
-> despesas
-> quitação
-> histórico
-> settled
```

### 18.5 Milestone E — Experiência Hotwire

Inclui fase 12.

Entrega:

```text
mesmo domínio
+ atualizações em tempo real
+ modais e navegação parcial
```

### 18.6 Milestone F — Demonstração e piloto

Inclui fases 13 e 14.

Entrega:

```text
grafo explicativo
+ acessibilidade
+ observabilidade
+ deploy público
```

---

## 19. Primeiros arquivos de spec

A primeira sequência recomendada é:

```text
spec/services/debt_simplifier_spec.rb
spec/services/equal_split_calculator_spec.rb
spec/services/expense_creator_spec.rb
spec/services/group_balance_calculator_spec.rb
spec/services/projected_balance_calculator_spec.rb
spec/services/payment_reporter_spec.rb
spec/services/payment_confirmer_spec.rb
spec/services/payment_canceller_spec.rb
spec/services/group_financial_status_resolver_spec.rb
```

Depois:

```text
spec/services/expense_corrector_spec.rb
spec/services/group_creator_spec.rb
spec/services/group_invitation_accepter_spec.rb
spec/services/membership_deactivator_spec.rb
spec/services/group_archiver_spec.rb
```

E então:

```text
spec/requests/expenses_spec.rb
spec/requests/payments_spec.rb
spec/requests/group_invitations_spec.rb
spec/system/group_settlement_spec.rb
```

---

## 20. O que não deve bloquear o início

Não é necessário implementar antes das primeiras specs:

- Tailwind final;
- design system completo;
- Turbo Streams;
- Action Cable;
- grafo;
- D3;
- solver exato;
- convites por link;
- Pix ou Stripe;
- multi-moeda;
- relatórios;
- analytics.

Também não é necessário decidir agora cada detalhe das fases futuras. Mudanças que afetem o ledger, estados ou promessa do MVP devem atualizar a documentação normativa antes da implementação.

---

## 21. Critério geral de pronto do MVP

O MVP técnico está pronto quando:

1. todas as fases até a 12 possuem specs verdes;
2. o fluxo funciona por HTTP sem Action Cable;
3. o mesmo fluxo funciona com Turbo Streams habilitados;
4. nenhuma sugestão é confundida com pagamento ocorrido;
5. reports não são sugeridos novamente;
6. concorrência e idempotência têm cobertura automatizada;
7. o grupo só aparece como quitado com saldo oficial zero e nenhuma pendência;
8. o fluxo operacional pode ser concluído por lista textual;
9. erros e ações obsoletas têm resposta compreensível;
10. um cenário contraintuitivo explica por que o destinatário sugerido difere do pagador lembrado;
11. despesas registradas por terceiros exibem creator, pagador e destaque contextual sem criar aprovação implícita;
12. o deploy público executa o cenário principal de ponta a ponta.

A visualização em grafo é um diferencial importante para o portfólio, mas não deve atrasar a comprovação do ciclo financeiro central.

---

## 22. Objetivos pós-MVP

### 22.1 Suporte a múltiplos idiomas

Após a conclusão do MVP, um dos objetivos do produto é disponibilizar a interface em múltiplos idiomas. A evolução deve incluir textos da interface, mensagens de validação e comunicação de estados financeiros; datas, números e valores devem ser apresentados conforme o locale selecionado.

Internacionalização não altera as regras do ledger: os valores continuam armazenados em unidades inteiras da menor denominação da moeda e a decisão de uma moeda por grupo permanece válida até que uma futura mudança de domínio a substitua explicitamente.

### 22.2 Critério para iniciar

O trabalho de internacionalização só deve começar depois que o gate geral do MVP estiver atendido. Antes da implementação, definir os locales iniciais, a estratégia de seleção e persistência de locale e as specs de apresentação necessárias, sem introduzir novas regras financeiras por inferência de idioma ou região.
