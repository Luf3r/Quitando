# Quitando — Especificação do Produto

Documento de especificação de um projeto de portfólio em Rails + Hotwire. A aplicação demonstra domínio de backend por meio de regras financeiras, consistência de dados e um problema real de otimização, sem se limitar a um CRUD com autenticação.

Consulte também o [índice da documentação](./00-index.md).

A sequência técnica de construção e as specs por etapa estão no [Roadmap de Implementação e Estratégia de Specs](./05-quitando-roadmap-implementacao.md).

## Navegação rápida

- [1. Visão geral](#1-visão-geral)
- [2. Casos de uso](#2-casos-de-uso)
- [3. Conceitos centrais](#3-conceitos-centrais)
- [4. Problema algorítmico](#4-problema-algorítmico)
- [5. Linha de base da comparação visual](#5-linha-de-base-da-comparação-visual)
- [6. Modelo funcional do MVP](#6-modelo-funcional-do-mvp)
- [7. Arquitetura de serviços](#7-arquitetura-de-serviços)
- [8. Stack técnica escolhida](#8-stack-técnica-escolhida)
- [9. MVP](#9-mvp)
- [10. Escopo posterior](#10-escopo-posterior)
- [11. Não escopo do MVP](#11-não-escopo-do-mvp)
- [12. Ordem de implementação](#12-ordem-de-implementação)
- [13. Testes prioritários](#13-testes-prioritários)
- [14. Hipóteses e validação de produto](#14-hipóteses-e-validação-de-produto)
- [15. Por que funciona como peça de portfólio](#15-por-que-funciona-como-peça-de-portfólio)

---


## 1. Visão geral

O Quitando é uma aplicação para grupos que compartilham despesas — viagens, repúblicas, eventos e projetos — registrarem quem pagou e como cada valor deve ser dividido.

A partir desses registros, o sistema:

1. calcula o saldo líquido oficial de cada participante;
2. mostra pagamentos já declarados e ainda aguardando confirmação;
3. gera um **plano simplificado de quitação** para o valor ainda não coberto;
4. permite registrar e confirmar os pagamentos efetivamente realizados;
5. indica quando as contas podem ser consideradas encerradas.

A aplicação é inspirada em produtos de divisão de contas, mas o diferencial de portfólio está na profundidade técnica: ledger auditável, projeções explícitas, algoritmo explicável, testes de invariantes, concorrência, idempotência e uma UI reativa construída com Hotwire.

### 1.1 O problema humano

Dividir uma conta isolada é simples. A dificuldade aparece quando um grupo acumula várias despesas, pagas por pessoas diferentes, e precisa encerrar a situação depois.

Nesse momento, o grupo precisa saber:

- quanto cada pessoa pagou e quanto lhe cabia;
- quem ainda deve e quem deve receber;
- para quem cada pagamento deve ser feito;
- quais transferências foram apenas sugeridas, declaradas ou confirmadas;
- quando as contas podem ser consideradas encerradas.

Planilhas ajudam na aritmética, mas normalmente deixam para o grupo o trabalho de reconstruir o histórico, coordenar pagamentos e cobrar confirmações. O Quitando busca reduzir essa carga cognitiva e o atrito social associado a dinheiro entre pessoas próximas.

O MVP pressupõe **grupos de confiança pré-existente**: amigos, familiares, casais, colegas de casa e equipes pequenas que já possuem uma relação fora do aplicativo. Ele organiza declarações colaborativas, mas não cria confiança entre desconhecidos, não funciona como prova bancária e não resolve disputas formais.

### 1.2 Proposta de valor

Em um grupo com muitas despesas, as obrigações podem formar diversas relações entre participantes. O Quitando consolida essas relações em saldos líquidos e gera um plano de quitação mais simples, claro e verificável.

> Menos contas para reconstruir, menos transferências para coordenar e mais clareza para encerrar as dívidas do grupo.

O produto **não promete que o modo padrão sempre encontra o menor número matematicamente possível de transferências**. A versão padrão usa um algoritmo guloso, rápido e previsível. Uma busca exata poderá ser oferecida posteriormente como modo de análise para instâncias pequenas.

### 1.3 Resultado esperado para o usuário

O ciclo principal não termina quando uma despesa é cadastrada. Ele termina quando o grupo passa por:

```text
despesas -> saldos -> plano -> pagamentos reportados -> confirmações -> grupo quitado
```

O documento [Problema, Casos de Uso e Hipóteses de Produto](./01-quitando-problema-casos-de-uso.md) detalha contextos reais, riscos e hipóteses.

---

## 2. Casos de uso

O produto pode ser usado em situações nas quais várias pessoas compartilham custos ao longo do tempo:

- viagens entre amigos ou familiares;
- repúblicas e apartamentos compartilhados;
- churrascos, festas, jantares e comemorações;
- casais que dividem parte das despesas;
- eventos, hackathons, bandas, equipes e projetos temporários;
- compras coletivas;
- caronas e deslocamentos recorrentes.

O valor aumenta quando existem três ou mais participantes, várias despesas, pagadores diferentes ou divisões que não incluem todo o grupo.

Para uma única conta dividida igualmente entre duas pessoas, uma calculadora ou um PIX dividido pode ser suficiente. O Quitando é mais útil quando o custo de coordenar o encerramento supera o custo da própria conta matemática.

---

## 3. Conceitos centrais

A aplicação separa conceitos que não devem ser confundidos:

- **Despesa:** fato registrado no grupo, com pagador, valor e participantes responsáveis.
- **Saldo oficial:** quanto uma pessoa deve receber ou pagar após despesas válidas e pagamentos confirmados.
- **Pagamento reportado:** declaração pendente de que uma transferência foi enviada; ainda exige confirmação.
- **Saldo projetado:** saldo oficial ajustado pelos pagamentos reportados, usado para mostrar o que restará caso sejam confirmados.
- **Transferência sugerida:** instrução temporária produzida pelo algoritmo a partir dos saldos projetados.
- **Pagamento confirmado:** transferência aceita pelo recebedor e incorporada ao ledger oficial.

O cálculo de saldos, a projeção de pagamentos pendentes e a geração do plano são responsabilidades diferentes.

### 3.1 Dívida percebida versus plano líquido

Uma pessoa pode associar mentalmente sua dívida ao pagador de uma despesa específica, enquanto o plano simplificado indica outro destinatário após compensar o grupo inteiro. Por exemplo, Carla pode sentir que deve a Diego pela hospedagem, mas receber a instrução de pagar Ana porque Ana terminou com o maior saldo credor.

Isso não é uma inconsistência do ledger: a obrigação histórica explica **como o saldo surgiu**, enquanto a transferência sugerida explica **como o grupo pode ser quitado agora**. O MVP mantém o plano líquido como fluxo operacional, mas a interface precisa explicar resultados contraintuitivos e a validação de produto deve medir se usuários aceitam pagar um destinatário diferente daquele a quem sentem dever diretamente.

---

## 4. Problema algorítmico

Cada participante possui um saldo:

- positivo: deve receber;
- negativo: deve pagar;
- zero: está em dia naquele estado.

A soma dos saldos oficiais e a soma dos saldos projetados devem ser zero.

### 4.1 Modo padrão — simplificação gulosa

O algoritmo casa o maior credor com o maior devedor, quita o menor valor entre os dois e repete até todos os saldos chegarem a zero.

```text
enquanto houver saldos diferentes de zero:
  credor = maior saldo positivo
  devedor = maior saldo negativo em módulo
  valor = mínimo entre o crédito e a dívida
  sugerir transferência devedor -> credor no valor calculado
  atualizar os dois saldos
```

Com duas filas de prioridade, uma para credores e outra para devedores, a implementação opera em `O(m log m)`, onde `m` é a quantidade de participantes com saldo não zero.

O resultado:

- quita todos os saldos válidos;
- usa no máximo `m - 1` transferências;
- é rápido e previsível;
- não garante o mínimo absoluto em todos os casos.

Empates são resolvidos de forma determinística pelo `user_id` recebido ou por uma ordem estável fornecida explicitamente ao serviço, para que a mesma entrada produza a mesma saída.

### 4.2 Modo exato — fase posterior

Uma versão exata poderá usar backtracking com poda, memoização e orçamento de execução. Ela deve:

- ser restrita a instâncias pequenas;
- possuir timeout configurável;
- informar quando o mínimo foi comprovado;
- usar o resultado guloso como fallback quando o orçamento for excedido;
- descartar o resultado se o estado financeiro mudar durante o cálculo.

A quantidade de participantes, isoladamente, não garante que a busca será rápida. O custo depende também da distribuição dos saldos.

### 4.3 Dinheiro e arredondamento

Todos os valores monetários são armazenados em unidades inteiras da menor denominação da moeda, como centavos. `float` não é usado.

Em uma divisão igual:

1. calcula-se a parte inteira por participante;
2. os centavos residuais são distribuídos por ordem estável;
3. se o pagador estiver incluído, ele recebe prioridade no primeiro centavo residual;
4. os demais seguem a ordem do membership.

A regra precisa ser visível no detalhe da despesa e coberta por testes. O objetivo não é eliminar o arredondamento, mas torná-lo reproduzível e auditável.

---

## 5. Linha de base da comparação visual

A interface não usa expressões vagas como “todo mundo pagando todo mundo”. As camadas são:

1. **Obrigações de despesas:** uma relação por share de não pagador em cada despesa ativa.
2. **Após compensação bilateral:** obrigações agregadas entre os mesmos pares e compensadas em sentidos opostos.
3. **Plano simplificado:** transferências sugeridas a partir dos saldos.

Exemplo:

```text
Obrigações de despesas: 12
Após compensação bilateral: 8
Plano simplificado inicial: 4
```

A porcentagem de redução sempre declara a base usada.

### Limite importante

As obrigações de despesas são uma visão explicativa da estrutura dos gastos; o plano acionável é uma visão do estado atual, que também considera pagamentos confirmados e reportados. Depois que o grupo começa a pagar, essas duas visões não devem ser apresentadas como uma única sequência causal sem contexto.

No MVP:

- antes de pagamentos, a tela pode destacar a redução entre as três camadas;
- desde o primeiro pagamento reportado, a tela prioriza **pagamentos aguardando confirmação**, **pagamentos confirmados** e **plano restante**;
- porcentagens históricas são ocultadas ou rotuladas como baseadas somente nas despesas.

---

## 6. Modelo funcional do MVP

### 6.1 Entidades principais

```text
Group
  has_many :memberships
  has_many :users, through: :memberships
  currency_code
  financial_state_version

Membership
  belongs_to :group
  belongs_to :user
  role
  status

GroupInvitation
  belongs_to :group
  belongs_to :invited_user, class_name: "User"
  belongs_to :invited_by, class_name: "User"
  status # pending, accepted, declined, revoked, expired
  expires_at

Expense
  belongs_to :group
  belongs_to :paid_by, class_name: "User"
  has_many :expense_shares
  amount_cents
  description
  occurred_on
  voided_at

ExpenseShare
  belongs_to :expense
  belongs_to :user
  amount_owed_cents

Payment
  belongs_to :group
  belongs_to :from_user, class_name: "User"
  belongs_to :to_user, class_name: "User"
  amount_cents
  status
  source_financial_state_version
  request_fingerprint
  reported_at
  confirmed_at
  cancelled_at
  idempotency_key
```

No MVP, o plano de quitação **não é persistido**. Ele é calculado sob demanda. Despesas, shares e pagamentos são persistidos; pagamentos `reported` são fatos de workflow, enquanto apenas os `confirmed` entram no saldo oficial. Convites não tornam alguém participante financeiro até serem aceitos.

### 6.2 Estados de pagamento

```text
reported -> confirmed
reported -> cancelled
```

- `reported`: o pagador declara que enviou um valor sugerido;
- `confirmed`: o recebedor confirma o recebimento;
- `cancelled`: pagador ou recebedor encerra a declaração pendente, registrando ator e motivo.

Somente pagamentos confirmados alteram o saldo oficial. Pagamentos reportados alteram apenas a projeção e o plano restante. Se novas despesas forem criadas enquanto existe uma pendência, ela permanece registrada; o novo plano pode mudar e a interface deve explicar essa mudança, sem cancelar automaticamente o report.

### 6.3 Situação derivada do grupo

```text
empty
open
awaiting_confirmation
settled
```

- `empty`: ainda não existe atividade financeira válida;
- `open`: existem saldos a resolver e nenhum pagamento pendente;
- `awaiting_confirmation`: existe ao menos um pagamento `reported`; a tela também informa se ainda restam transferências adicionais;
- `settled`: existe atividade financeira, todos os saldos oficiais são zero e não há pagamentos `reported`.

---

## 7. Arquitetura de serviços

### `GroupBalanceCalculator`

Calcula saldos oficiais a partir de despesas ativas, shares e pagamentos confirmados.

```ruby
GroupBalanceCalculator.call(group) # => { user_id => official_balance_cents }
```

### `ProjectedBalanceCalculator`

Aplica pagamentos `reported` aos saldos oficiais sem alterar o ledger.

```ruby
ProjectedBalanceCalculator.call(official_balances, reported_payments)
# => { user_id => projected_balance_cents }
```

### `DebtSimplifier`

Ruby puro, sem ActiveRecord. Recebe saldos prontos e devolve transferências sugeridas.

```ruby
class DebtSimplifier
  Transfer = Data.define(:from_user_id, :to_user_id, :amount_cents)

  def initialize(balances)
    @balances = balances.dup
  end

  def call
    # algoritmo guloso determinístico
  end
end
```

O plano acionável usa saldos projetados, evitando sugerir novamente um pagamento que já está aguardando confirmação.

### `ObligationGraphBuilder`

Constrói obrigações de despesas e a compensação bilateral para a visualização explicativa. Não é usado como fonte do saldo oficial.

### `PaymentReporter`, `PaymentConfirmer` e `PaymentCanceller`

Validam autorização, versão financeira, transições de estado, valor permitido, concorrência e idempotência.

### `GroupCreator` e serviços de convite

Criam o owner inicial, registram convites internos e criam ou reativam membership apenas depois da aceitação.

### `GroupFinancialStatusResolver`

Deriva `empty`, `open`, `awaiting_confirmation` ou `settled`; arquivamento é uma condição operacional separada.

### Princípio arquitetural

O ledger oficial é a fonte de verdade para saldos confirmados. Pagamentos pendentes formam uma projeção explícita. Grafos e sugestões são recalculáveis. Nenhuma sugestão é tratada como pagamento ocorrido.

---

## 8. Stack técnica escolhida

| Camada | Tecnologia |
|---|---|
| Framework | Rails 8.x |
| Frontend reativo | Turbo + Stimulus |
| Real-time | Action Cable + Turbo Streams |
| Adapter de real-time | Solid Cable |
| Jobs | Active Job + Solid Queue |
| Banco | PostgreSQL 18 |
| Autenticação | Devise |
| Autorização | Pundit |
| UI | ViewComponent + Tailwind CSS |
| Testes | RSpec + testes de propriedades/invariantes |
| Deploy | Kamal |

A combinação Solid Queue + Solid Cable mantém a arquitetura inicial sem Redis. Redis e Sidekiq só entram se houver necessidade observável de escala ou operação.

---

## 9. MVP

O primeiro release fecha o ciclo completo:

1. cadastro e autenticação;
2. criação de grupos, convite interno de usuários cadastrados e memberships;
3. despesas divididas igualmente ou por valor exato;
4. cálculo de saldos oficiais;
5. projeção de pagamentos pendentes;
6. plano de quitação guloso e determinístico;
7. registro de pagamento a partir de uma sugestão atual;
8. confirmação ou cancelamento pelo participante autorizado;
9. inativação e reativação segura de memberships;
10. histórico de despesas e pagamentos;
11. visualização textual obrigatória e grafo complementar;
12. atualização por Turbo Streams como melhoria progressiva;
13. testes das regras centrais, concorrência e invariantes.

### 9.1 Critérios de sucesso

O MVP está completo quando um grupo consegue:

- convidar um usuário cadastrado, aceitar o convite e impedir memberships duplicados;
- registrar despesas e visualizar saldos corretos;
- distinguir saldo oficial, pagamento pendente e saldo projetado;
- obter sugestões sem repetir valores já reportados;
- registrar pagamentos parciais ou totais dentro do valor sugerido;
- confirmar ou cancelar uma declaração uma única vez;
- chegar novamente a saldo oficial zero;
- recarregar qualquer página e obter o estado correto sem depender de WebSocket;
- receber mensagem clara quando tenta agir sobre um plano obsoleto;
- impedir arquivamento enquanto houver saldo, pendência ou convite aberto;
- reativar o mesmo membership depois de uma saída válida;
- executar a quitação por lista textual, sem depender do grafo;
- explicar por que o destinatário sugerido pode ser diferente do pagador de uma despesa lembrada;
- distinguir claramente quem registrou e quem pagou uma despesa criada por terceiro.

---

## 10. Escopo posterior

### Fase 2 — profundidade técnica

- splits por porcentagem e por partes;
- solver exato com timeout e fallback;
- comparação guloso versus ótimo;
- modo “como chegamos a este plano?”;
- benchmarks e property-based tests mais amplos;
- reversão vinculada de pagamento confirmado;
- histórico mais rico para correções e ajustes;
- cálculo assíncrono versionado;
- ciclos formais de quitação para grupos contínuos;
- modo opcional de acerto direto, caso a validação mostre que preservar relações históricas é mais importante para alguns grupos que reduzir transferências.

### Fase 3 — produto

- participantes convidados sem conta;
- links públicos com token, expiração e escopo limitado;
- despesas recorrentes;
- disputas, aprovação obrigatória de despesas e uso entre partes sem confiança prévia;
- notificações e resumos;
- multi-moeda.
- interface em múltiplos idiomas, com localização de textos, datas, números e apresentação monetária sem alterar o ledger.

### Fase 4 — integrações

- pagamento por Pix ou Stripe;
- webhooks idempotentes;
- API pública;
- webhooks de saída;
- exportação em CSV ou PDF;
- analytics.

---

## 11. Não escopo do MVP

- busca exata pelo mínimo absoluto;
- multi-moeda;
- participantes sem conta e convites por link público;
- link público de cobrança;
- pagamento bancário integrado;
- pagamento arbitrário fora do plano atual;
- reversão de pagamento já confirmado;
- disputas;
- aprovação obrigatória de despesas e uso entre partes sem confiança prévia;
- modo de acerto direto fora do plano líquido;
- despesas recorrentes automáticas;
- fechamento contábil por período;
- API pública e webhooks externos;
- relatórios avançados;
- analytics ou ranking de comportamento.

Cada grupo utiliza uma única moeda, definida na criação e imutável enquanto existir qualquer despesa ou pagamento registrado. O MVP só convida contas já cadastradas; convites aparecem dentro do aplicativo e não criam shares antes da aceitação. Um grupo só pode ser arquivado quando estiver vazio ou quitado, sem pagamentos ou convites pendentes. O modelo de colaboração assume grupos de confiança: qualquer membro ativo pode registrar uma despesa indicando outro membro ativo como pagador, mas autoria e pagador são sempre exibidos separadamente. O destaque contextual no dashboard/feed é derivado da própria despesa e não equivale ao sistema de notificações por e-mail, push ou digest previsto para uma fase posterior.

---

## 12. Ordem de implementação

O roadmap das seções anteriores define **escopo de produto**, não a ordem em que o código deve ser escrito. A implementação começa pelas regras de maior risco e mantém specs junto de cada etapa:

```text
fundação e CI
-> DebtSimplifier puro
-> schema e constraints
-> criação de despesas e arredondamento
-> saldo oficial
-> primeiro plano
-> saldo projetado
-> workflow concorrente de pagamentos
-> estados do grupo e correções
-> memberships e convites
-> HTTP e policies
-> Hotwire e real-time
-> grafo, acessibilidade e deploy
```

O documento [Roadmap de Implementação e Estratégia de Specs](./05-quitando-roadmap-implementacao.md) contém dependências, arquivos de spec e critérios de saída por fase. Testes não são uma etapa final do MVP; cada fase só avança depois de seus contratos centrais estarem verdes.

---

## 13. Testes prioritários

### 13.1 Ledger e projeção

- a soma das shares é igual ao valor da despesa;
- a soma dos saldos oficiais é zero;
- a soma dos saldos projetados é zero;
- somente pagamentos confirmados alteram o saldo oficial;
- pagamentos reportados alteram a projeção na direção correta;
- cancelar um reportado restaura a projeção;
- todos os participantes pertencem ao grupo e estão ativos ao criar o fato;
- a despesa produz ao menos uma obrigação para não pagador;
- valores são inteiros positivos, convertidos de texto decimal sem `float`.

### 13.2 Simplificador

- todas as transferências têm valor positivo;
- origem e destino são diferentes;
- o resultado zera todos os saldos;
- o valor total é conservado;
- a entrada não é modificada;
- a mesma entrada gera a mesma saída;
- a quantidade de transferências é no máximo `m - 1`.

### 13.3 Concorrência

- duas submissões com a mesma chave não duplicam pagamento;
- dois reports concorrentes não ultrapassam a sugestão disponível;
- duas confirmações simultâneas produzem uma única transição;
- uma versão financeira obsoleta não grava uma sugestão antiga;
- criação append-only de despesa concorrente é serializada, mas não rejeitada apenas por versão;
- uma idempotency key reutilizada com payload diferente é rejeitada;
- broadcasts são emitidos apenas depois do commit.

---

## 14. Hipóteses e validação de produto

O projeto parte das hipóteses de que:

- grupos têm dificuldade para encerrar despesas quando várias pessoas pagaram itens diferentes;
- instruções explícitas são mais úteis que apenas mostrar saldos;
- reduzir transferências é percebido como benefício;
- confirmação pelo recebedor aumenta confiança;
- lista textual é mais importante para executar pagamentos, enquanto o grafo é mais útil para compreensão e demonstração;
- o fluxo de registro precisa ser rápido o suficiente para uso no momento da despesa;
- convidar e aceitar a entrada no grupo não pode exigir um fluxo mais complexo que a própria quitação;
- a impossibilidade de reverter pagamento confirmado no MVP precisa ser compreendida e não gerar erros frequentes;
- usuários aceitam pagar o destinatário indicado pelo saldo líquido mesmo quando ele não é o pagador da despesa que originou sua percepção de dívida;
- grupos de confiança aceitam registros colaborativos em nome de outro pagador quando `registrado por` e `pago por` permanecem transparentes e o pagador recebe um aviso contextual no aplicativo.

O principal indicador de sucesso não é a quantidade de despesas cadastradas, mas quantos grupos chegam a saldo zero com poucas correções e sem reconstrução manual.

---

## 15. Por que funciona como peça de portfólio

- possui um núcleo algorítmico real sem prometer mais do que entrega;
- separa saldo oficial, projeção pendente e plano acionável;
- exige decisões sobre dinheiro, idempotência, concorrência e autorização;
- demonstra Rails e Hotwire sem transformar o frontend em SPA pesada;
- permite apresentar visualmente o impacto e os limites do algoritmo;
- oferece uma narrativa clara: fato financeiro → saldo oficial → projeção → plano → confirmação.
