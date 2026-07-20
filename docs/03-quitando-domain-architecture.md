# Quitando — Domínio, Ledger e Arquitetura

Este documento é o contrato normativo entre banco, serviços, controllers, jobs e interface. Em caso de divergência sobre fórmulas, invariantes ou estados, este documento prevalece.

A arquitetura sustenta uma promessa específica: permitir que um grupo passe de um histórico de despesas para um encerramento verificável. Para isso, distingue fatos confirmados, declarações pendentes e projeções recalculáveis.

Consulte também o [índice da documentação](./00-index.md) e os [ADRs](./adr/).

## Navegação rápida

- [1. Glossário](#1-glossário)
- [2. Convenção de sinais e fórmulas](#2-convenção-de-sinais-e-fórmulas)
- [3. Situação derivada do grupo](#3-situação-derivada-do-grupo)
- [4. Fronteira de confiança do MVP](#4-fronteira-de-confiança-do-mvp)
- [5. Invariantes obrigatórias](#5-invariantes-obrigatórias)
- [6. Entidades e campos sugeridos](#6-entidades-e-campos-sugeridos)
- [7. Estados e transições](#7-estados-e-transições)
- [8. Serviços de domínio](#8-serviços-de-domínio)
- [9. Concorrência, versão e idempotência](#9-concorrência-versão-e-idempotência)
- [10. Autorização mínima](#10-autorização-mínima)
- [11. Segurança e privacidade mínimas](#11-segurança-e-privacidade-mínimas)
- [12. Comparação visual e limites semânticos](#12-comparação-visual-e-limites-semânticos)
- [13. Contratos de teste](#13-contratos-de-teste)
- [14. Observabilidade mínima](#14-observabilidade-mínima)
- [15. Decisões explicitamente adiadas](#15-decisões-explicitamente-adiadas)

---


## 1. Glossário

### 1.1 Grupo

Contexto isolado no qual usuários compartilham despesas. Cada grupo usa uma única moeda no MVP.

### 1.2 Membership

Relação entre usuário e grupo, com papel e estado. Registros com histórico financeiro não são excluídos fisicamente. Uma pessoa inativada volta ao grupo reativando o mesmo membership, em vez de criar outro.

### 1.3 Convite de grupo

Solicitação para que um usuário já cadastrado entre no grupo. No MVP, o convite é interno ao aplicativo: somente depois de aceito ele cria ou reativa um membership. Convidados sem conta e links públicos continuam fora do escopo.

### 1.4 Despesa

Fato de que um usuário pagou determinado valor em benefício de um conjunto de participantes.

### 1.5 Share

Parcela de uma despesa atribuída a um participante. A soma das shares é exatamente o valor da despesa.

### 1.6 Obrigação de despesa

Relação produzida por uma share de não pagador. Se Ana paga R$ 90 e as shares são Ana R$ 30, Bruno R$ 30 e Carla R$ 30, as obrigações são Bruno → Ana por R$ 30 e Carla → Ana por R$ 30.

### 1.7 Ledger oficial

Conjunto de fatos que determinam o saldo confirmado: despesas ativas, shares e pagamentos `confirmed`. Pagamentos `reported` são persistidos, mas não fazem parte do saldo oficial.

### 1.8 Saldo oficial

Resultado agregado do ledger oficial:

- positivo: deve receber;
- negativo: deve pagar;
- zero: está em dia.

### 1.9 Pagamento reportado

Declaração de que uma transferência foi enviada e aguarda confirmação. Não altera o saldo oficial.

### 1.10 Saldo projetado

Saldo oficial ajustado por pagamentos `reported`. Representa o que restará se todas as declarações pendentes forem confirmadas.

### 1.11 Compensação bilateral

Agregação e compensação de obrigações de despesas entre o mesmo par em direções opostas. É uma visão explicativa, não a fonte do saldo.

### 1.12 Plano de quitação

Projeção temporária que transforma saldos projetados em transferências sugeridas. Não é um fato financeiro e não altera o ledger. O destinatário pode ser diferente do pagador de qualquer despesa específica, porque o plano opera sobre saldos líquidos do grupo.

### 1.13 Dívida percebida

Associação mental do usuário entre uma despesa específica e quem a pagou. Pode divergir do plano líquido sem que exista erro contábil. É um conceito de UX e validação de produto, não uma entidade persistida nem uma regra do ledger.

### 1.14 `financial_state_version`

Inteiro monotônico do grupo. É incrementado por qualquer mudança financeiramente material que possa alterar saldo oficial, saldo projetado, pendências ou plano: criar, substituir ou anular despesa; reportar, confirmar ou cancelar pagamento. Alterações meramente descritivas não precisam invalidar o plano.

### 1.15 Grupo quitado

Estado derivado em que existe atividade financeira, todos os saldos oficiais são zero e não há pagamentos `reported`.

---

## 2. Convenção de sinais e fórmulas

### 2.1 Saldo oficial

Para cada usuário:

```text
saldo_oficial = total_pago_em_despesas
              - total_das_proprias_shares
              + pagamentos_confirmados_enviados
              - pagamentos_confirmados_recebidos
```

Exemplo:

```text
Despesa: R$ 90
Pagadora: Ana
Shares: Ana R$ 30, Bruno R$ 30, Carla R$ 30

Ana:   90 - 30 = +60
Bruno:  0 - 30 = -30
Carla:  0 - 30 = -30
```

Se Bruno paga R$ 20 para Ana e Ana confirma:

```text
Ana:   +60 - 20 = +40
Bruno: -30 + 20 = -10
Carla: -30      = -30
```

A soma permanece zero.

### 2.2 Saldo projetado

Para cada usuário:

```text
saldo_projetado = saldo_oficial
                 + pagamentos_reportados_enviados
                 - pagamentos_reportados_recebidos
```

Se Bruno reporta R$ 10 para Ana, antes da confirmação:

```text
Oficial:   Ana +40, Bruno -10, Carla -30
Projetado: Ana +30, Bruno   0, Carla -30
```

O pagamento continua pendente, mas o plano acionável não sugere novamente os mesmos R$ 10.

### 2.3 Conservação

- soma dos saldos oficiais = zero;
- soma dos saldos projetados = zero;
- qualquer transferência sugerida preserva a soma zero.

---

## 3. Situação derivada do grupo

A situação não é persistida como fonte de verdade.

```text
empty
open
awaiting_confirmation
settled
```

Regras:

Primeiro define-se `has_financial_activity` como a existência de ao menos uma despesa não anulada ou um pagamento `reported`/`confirmed`. Pagamentos cancelados e despesas anuladas, isoladamente, permanecem no histórico, mas não tornam o grupo financeiramente ativo.

- `empty`: `has_financial_activity` é falso;
- `awaiting_confirmation`: existe pelo menos um pagamento `reported`;
- `settled`: `has_financial_activity` é verdadeiro, todos os saldos oficiais são zero e não existe `reported`;
- `open`: qualquer outro caso com saldo oficial não zero.

Um grupo arquivado mantém sua situação financeira derivada; `archived` é uma condição operacional separada, não um quinto estado financeiro.

`awaiting_confirmation` não implica que o saldo projetado já seja zero. A interface deve informar separadamente:

- valor aguardando confirmação;
- saldo projetado restante;
- quantidade de transferências adicionais sugeridas.

---

## 4. Fronteira de confiança do MVP

O domínio assume grupos de confiança pré-existente. Qualquer membro ativo pode registrar uma despesa e indicar outro membro ativo como pagador, mas:

- `created_by_user_id` e `paid_by_user_id` são fatos distintos e auditáveis;
- a interface nunca apresenta o creator como se fosse o pagador;
- o pagador indicado vê um aviso contextual derivado da despesa no dashboard/feed;
- se estiver conectado, o aviso pode ser entregue depois do commit por Turbo Stream; o estado também precisa aparecer no próximo carregamento HTTP;
- correções financeiras preservam autoria, motivo e cadeia de substituição;
- o registro produz efeito imediatamente, sem aprovação do pagador no MVP;
- contestação, rejeição e aprovação obrigatória ficam fora do escopo.

Essa escolha reduz fricção em grupos colaborativos, mas torna o produto inadequado para desconhecidos ou relações adversariais. Ela é uma premissa de produto, não uma garantia de segurança contra participantes mal-intencionados. E-mail, push e central persistente de notificações continuam fora do MVP.

---

## 5. Invariantes obrigatórias

### 5.1 Dinheiro

- valores usam inteiros na menor unidade da moeda;
- na Fase 0, o parser aceita somente texto positivo no formato `pt-BR`: inteiro sem separador (`12`), inteiro com grupos de milhar completos (`1.234`) e, opcionalmente, vírgula seguida de exatamente dois dígitos (`1.234,56`);
- texto vazio, zero, sinal, ponto decimal, grupos de milhar incompletos, mais de duas casas ou caracteres não numéricos são inválidos;
- o parser converte texto diretamente para centavos e rejeita entradas que não sejam texto; não aceita nem usa `float`;
- despesas, shares e pagamentos têm valor maior que zero;
- a soma das shares é exatamente o valor da despesa;
- a moeda do fato é a moeda do grupo;
- arredondamento segue ordem determinística e visível.

### 5.2 Participação

- pagador, participantes, origem e destino pertencem ao mesmo grupo e possuem membership ativo no momento de um novo fato;
- creator e pagador são registrados separadamente quando pessoas diferentes;
- origem e destino de pagamento são diferentes;
- membership com histórico não é excluído fisicamente;
- usuário inativo não recebe novas despesas nem inicia pagamentos;
- membership só pode ser inativado quando saldo oficial e projetado são zero e não há pagamento pendente envolvendo o usuário;
- membership inativo pode ser reativado pelo owner, reutilizando o mesmo registro;
- o último owner não pode sair ou ser inativado sem transferir a propriedade;
- um grupo só pode ser arquivado quando estiver `empty` ou `settled`, sem convites pendentes nem pagamentos `reported`.

### 5.3 Ledger e projeção

- soma dos saldos oficiais é zero;
- soma dos saldos projetados é zero;
- somente `confirmed` altera saldo oficial;
- `reported` altera somente projeção e plano restante;
- cancelar `reported` remove seu efeito projetado;
- uma pendência já criada continua sendo uma declaração factual mesmo se novas despesas mudarem o plano; ela não é cancelada automaticamente;
- a projeção pode, nesses casos, atravessar zero e produzir uma sugestão posterior em sentido oposto; a UI deve mostrar a pendência separadamente e explicar o recalculo;
- sugestões nunca são persistidas como pagamentos;
- fatos confirmados não são modificados silenciosamente;
- correções registram ator, motivo e relação com o fato corrigido.

### 5.4 Pagamento reportado

No MVP:

- nasce de uma transferência do plano acionável atual;
- pagador e recebedor possuem memberships ativos;
- `0 < amount_cents <= suggested_amount_cents`;
- origem deve possuir saldo projetado negativo;
- destino deve possuir saldo projetado positivo;
- a requisição informa `expected_financial_state_version`;
- o servidor recalcula o plano dentro da transação antes de aceitar;
- dois reports concorrentes não podem reservar o mesmo valor.

### 5.5 Simplificador

- entrada possui soma zero;
- identificadores são strings UUID v7 canônicas, minúsculas e com variante RFC válida;
- saldos zero são ignorados;
- cada transferência tem valor positivo;
- origem e destino são diferentes;
- aplicar todas as transferências zera todos os saldos;
- entrada não é modificada;
- empates de mesma magnitude seguem UUID crescente em ordem lexicográfica;
- quantidade de transferências não excede `m - 1`.

### 5.6 Despesa válida

- possui pelo menos uma share;
- a soma das shares é igual ao total;
- ao menos uma share pertence a pessoa diferente do pagador, evitando fatos sem efeito no grupo;
- o pagador pode ou não possuir share;
- entrada monetária é recebida como texto decimal localizado e convertida diretamente para inteiro, sem passar por `float`.

---

## 6. Entidades e campos sugeridos

Todas as chaves primárias das entidades usam o tipo PostgreSQL `uuid` com default explícito `uuidv7()`. Todas as foreign keys usam `uuid`. Ruby representa esses identificadores como strings canônicas minúsculas. A configuração global dos generators Rails usa `primary_key_type: :uuid`, mas cada migration continua responsável por declarar `default: -> { "uuidv7()" }`; o default UUID v4 implícito não satisfaz o contrato.

### 6.1 `groups`

```text
id
name
currency_code
financial_state_version  # bigint
archived_at
created_at
updated_at
```

`currency_code` é imutável depois da primeira despesa ou pagamento.

### 6.2 `memberships`

```text
id
group_id
user_id
role          # owner, member
status        # active, inactive
created_at
updated_at
```

Constraints:

- `unique(group_id, user_id)`;
- ao menos um owner ativo por grupo não arquivado.

A segunda regra é uma invariável transacional protegida pelo lock do grupo; não deve ser descrita como um `CHECK` simples entre linhas.

### 6.3 `group_invitations`

```text
id
group_id
invited_user_id
invited_by_user_id
status        # pending, accepted, declined, revoked, expired
expires_at
accepted_at
revoked_at
created_at
updated_at
```

Constraints:

- apenas owner ativo cria ou revoga;
- `invited_user_id` identifica uma conta já existente;
- no máximo um convite `pending` por grupo e usuário;
- não é criado convite para usuário que já possui membership ativo;
- aceitar cria um membership ou reativa o existente, sempre dentro de transação;
- o convidado só pode aceitar ou recusar o próprio convite.

### 6.4 `expenses`

```text
id
group_id
paid_by_user_id
amount_cents    # bigint
description
occurred_on
created_by_user_id
voided_at
voided_by_user_id
void_reason
replaces_expense_id
created_at
updated_at
```

O `GroupBalanceCalculator` ignora despesas anuladas, mas seus registros e shares permanecem para auditoria.

### 6.5 `expense_shares`

```text
id
expense_id
user_id
amount_owed_cents  # bigint
position
created_at
updated_at
```

Constraints:

- `unique(expense_id, user_id)`;
- `amount_owed_cents > 0`;
- a soma por despesa é validada na mesma transação.

`position` preserva uma ordem estável para arredondamento e apresentação.

### 6.6 `payments`

```text
id
group_id
from_user_id
to_user_id
amount_cents    # bigint
status
idempotency_key
request_fingerprint
source_financial_state_version
reported_by_user_id
reported_at
confirmed_by_user_id
confirmed_at
cancelled_by_user_id
cancelled_at
cancellation_reason
created_at
updated_at
```

Constraints:

- `amount_cents > 0`;
- `from_user_id <> to_user_id`;
- `idempotency_key` é um UUID globalmente único;
- repetir a chave com payload diferente falha por conflito de `request_fingerprint`;
- foreign keys obrigatórias;
- índices por `group_id`, `status`, `reported_at` e `confirmed_at`.

---

## 7. Estados e transições

### 7.1 Payment

```text
reported -> confirmed
reported -> cancelled
```

Regras:

- somente o pagador reporta no MVP;
- somente o recebedor confirma;
- pagador ou recebedor pode cancelar enquanto `reported`;
- cancelamento registra ator e motivo;
- `confirmed` e `cancelled` são terminais no MVP;
- reversão ou correção de um pagamento já confirmado não existe no primeiro release; a UI exige confirmação explícita e a limitação é declarada;
- uma fase posterior poderá criar um evento compensatório vinculado ao original, nunca reabrir ou apagar silenciosamente o pagamento confirmado.

### 7.2 Membership

```text
active -> inactive
inactive -> active
```

A inativação é bloqueada se o usuário possuir saldo oficial/projetado diferente de zero ou pagamento pendente. O último owner deve transferir a propriedade antes de sair. A reativação reutiliza o mesmo membership e exige ação do owner.

### 7.3 GroupInvitation

```text
pending -> accepted
pending -> declined
pending -> revoked
pending -> expired
```

Convite aceito, recusado, revogado ou expirado é terminal. O convidado recusa o próprio convite; o owner revoga. Ao tentar listar ou aceitar um convite após `expires_at`, o sistema o marca como `expired` de forma idempotente; um job de limpeza é opcional. Um novo convite pode ser criado posteriormente se ainda não houver membership ativo.

### 7.4 Expense

```text
active -> voided
```

- campos financeiros — valor, pagador e shares — nunca são sobrescritos depois da criação;
- uma correção financeira anula a despesa e cria uma substituta na mesma transação, com motivo, ator e `replaces_expense_id`;
- campos puramente descritivos podem ser alterados com auditoria sem incrementar a versão financeira;
- correções podem ocorrer mesmo com pagamentos pendentes ou confirmados: esses pagamentos permanecem fatos independentes, e o sistema recalcula oficial, projeção e plano.

Essa regra evita a noção ambígua de pagamento “relacionado” a uma despesa específica, já que a quitação acontece sobre saldos líquidos.

---

## 8. Serviços de domínio

### 8.1 `GroupBalanceCalculator`

Entrada: grupo ou coleção imutável de fatos oficiais.

Saída:

```ruby
{ user_id => official_balance_cents }
```

Responsabilidades:

- agregar despesas ativas e shares;
- aplicar somente pagamentos confirmados;
- validar soma zero em testes e observabilidade;
- não decidir quem paga quem.

### 8.2 `ProjectedBalanceCalculator`

Entrada:

- saldos oficiais;
- pagamentos `reported`.

Saída:

```ruby
{ user_id => projected_balance_cents }
```

Responsabilidades:

- aplicar o efeito provisório dos reports;
- preservar soma zero;
- não persistir nem confirmar pagamentos.

### 8.3 `DebtSimplifier`

Entrada:

```ruby
{ user_id => balance_cents }
```

Tipos públicos:

```ruby
Hash<String, Integer>
```

Cada `user_id` é UUID v7 canônica, minúscula e com variante RFC válida. A validação ocorre na ordem: estrutura, IDs, saldos e soma zero.

Saída:

```ruby
[
  Transfer.new(from_user_id:, to_user_id:, amount_cents:)
]
```

Responsabilidades:

- validar soma zero;
- produzir saída determinística;
- desempatar saldos de mesma magnitude pela ordem lexicográfica crescente do UUID;
- não consultar banco;
- não persistir pagamentos;
- opcionalmente produzir trace para auditoria.

O plano acionável usa o saldo projetado. Um modo técnico pode calcular também o plano oficial para comparação, desde que a UI deixe claro que pagamentos pendentes ainda não foram confirmados.

### 8.4 `ObligationGraphBuilder`

Responsabilidades:

- produzir uma obrigação por share de não pagador em despesas ativas;
- preservar a distinção entre obrigações históricas e transferências do plano líquido;
- agregar relações do mesmo par;
- compensar sentidos opostos;
- fornecer dados para visualização, sem substituir o cálculo de saldo.

### 8.5 `GroupFinancialStatusResolver`

Calcula `empty`, `open`, `awaiting_confirmation` ou `settled` a partir do predicado explícito de atividade, saldos oficiais e reports.

### 8.6 `GroupCreator`

Cria o grupo e o membership `owner/active` do usuário na mesma transação. Um grupo nunca existe sem owner inicial.

### 8.7 `ExpenseCreator` e `ExpenseCorrector`

Responsabilidades:

- verificar autorização e memberships ativos;
- exigir que a despesa produza ao menos uma obrigação para não pagador;
- reconciliar shares;
- persistir em transação;
- incrementar `financial_state_version` atomicamente em mudanças financeiras;
- manter reports existentes e recalcular a projeção quando a despesa muda;
- emitir broadcast depois do commit.

### 8.8 `GroupInvitationCreator`, `GroupInvitationAccepter` e `MembershipReactivator`

Responsabilidades:

- limitar criação e revogação de convites ao owner;
- aceitar somente convite do próprio usuário;
- impedir memberships duplicados;
- criar ou reativar membership na mesma transação;
- não tratar convite pendente como participante financeiro.

### 8.9 `PaymentReporter`

Responsabilidades:

- adquirir lock do grupo;
- validar idempotência e versão esperada;
- recalcular saldos projetados e plano atual;
- aceitar apenas par e valor ainda sugeridos;
- criar `reported`;
- incrementar `financial_state_version`;
- não alterar saldo oficial.

### 8.10 `PaymentConfirmer`

Responsabilidades:

- adquirir lock ou fazer atualização condicional;
- garantir transição única para `confirmed`;
- verificar que o ator é o recebedor;
- registrar ator e timestamp;
- incrementar `financial_state_version`;
- emitir broadcast depois do commit.

### 8.11 `PaymentCanceller`

Responsabilidades:

- permitir cancelamento somente de `reported`;
- validar que o ator é pagador ou recebedor;
- registrar motivo;
- incrementar `financial_state_version`;
- devolver o valor reservado ao plano projetado.

---

## 9. Concorrência, versão e idempotência

### 9.1 Serialização por grupo

Comandos que alteram o estado financeiro usam lock da linha de `groups` ou mecanismo equivalente. Isso simplifica a garantia de que duas ações não reservem ou confirmem o mesmo saldo simultaneamente.

### 9.2 Versão obsoleta

Comandos que dependem de uma decisão calculada — reportar pagamento e corrigir financeiramente uma despesa — enviam `expected_financial_state_version`. A criação append-only de uma nova despesa não é rejeitada apenas porque outra despesa foi criada em paralelo; ela é serializada e revalidada quanto a memberships e shares.

Dentro da transação:

1. o grupo é bloqueado;
2. a versão atual é comparada;
3. regras e plano são recalculados;
4. se a ação não continuar válida, nada é persistido;
5. a resposta informa que o estado mudou e apresenta o plano atual.

A versão é uma proteção contra decisão obsoleta, não substitui as validações de domínio.

### 9.3 Duplo clique

Operações sensíveis recebem chave de idempotência e fingerprint canônico do payload. Repetir a mesma chave com o mesmo payload retorna o resultado já criado; reutilizá-la com payload diferente retorna conflito e não reaproveita o comando anterior.

### 9.4 Confirmações simultâneas

A confirmação usa lock ou atualização condicional:

```text
UPDATE payments
SET status = 'confirmed'
WHERE id = ? AND status = 'reported'
```

Apenas uma execução realiza a transição.

### 9.5 Broadcasts

Broadcasts são emitidos depois do commit. Informam que o estado mudou, mas não são fonte de verdade.

### 9.6 Cálculos assíncronos futuros

O solver exato registra `financial_state_version`. O resultado só é publicado se a versão ainda for atual; caso contrário, é marcado como obsoleto.

---

## 10. Autorização mínima

### 10.1 Grupo

- apenas membros ativos acessam dados financeiros do grupo;
- owner gerencia nome, convites, arquivamento e memberships;
- membro pode solicitar a própria saída, sujeita às mesmas invariantes financeiras;
- último owner não pode sair sem transferência de propriedade;
- arquivamento só é permitido quando o grupo está `empty` ou `settled`, sem pendências ou convites abertos;
- grupo arquivado é somente leitura no MVP;
- owner pode restaurar um grupo arquivado; restaurar não altera saldos, histórico ou moeda.

### 10.2 Despesa

- qualquer membro ativo pode registrar uma despesa porque o MVP pressupõe grupos de confiança;
- o pagador informado pode ser outro membro ativo, mas `created_by_user_id` e `paid_by_user_id` são sempre exibidos separadamente quando diferem;
- o pagador indicado recebe destaque contextual no app depois do commit; ausência de resposta não bloqueia nem aprova a despesa;
- creator, pagador ou owner pode iniciar correção financeira;
- ocultar botão não substitui regra de backend;
- pagador e participantes pertencem ao grupo;
- correção registra ator e motivo;
- contestação por participante afetado fica fora do MVP.

### 10.3 Pagamento

- somente origem reporta;
- somente destino confirma;
- origem ou destino cancela uma pendência;
- owner não confirma em nome de outro usuário no MVP.

### 10.4 Action Cable

A subscription verifica membership antes de transmitir eventos. Conhecer o identificador do stream não concede acesso.

---

## 11. Segurança e privacidade mínimas

- proteção CSRF;
- autorização em todas as ações mutáveis;
- rate limiting para login e operações sensíveis quando aplicável;
- logs sem tokens, descrições sensíveis ou dados financeiros desnecessários;
- valores monetários nunca aceitos como float;
- IDs de grupo e usuário sempre verificados contra relacionamentos;
- convites usam referência a usuário existente, sem autocomplete público de contas;
- eventos relevantes registram ator e timestamp;
- payloads de broadcast contêm apenas o necessário para renderizar componentes autorizados;
- exportação, links públicos e pagamentos externos permanecem fora do MVP.

Quando links públicos forem adicionados, exigirão token armazenado como digest, expiração, revogação, escopo mínimo e prevenção de replay.

---

## 12. Comparação visual e limites semânticos

`ObligationGraphBuilder` responde “como as despesas criaram relações”. `GroupBalanceCalculator` responde “qual é o saldo oficial”. `ProjectedBalanceCalculator` responde “o que restará após pendências”. `DebtSimplifier` responde “quais transferências ainda são sugeridas”.

Essas respostas são relacionadas, mas não intercambiáveis. Uma obrigação histórica pode apontar para Diego enquanto o plano restante aponta para Ana; isso é válido quando ambos derivam do mesmo saldo líquido e deve ser explicado pela interface.

Assim que existe qualquer pagamento `reported`, a comparação histórica deixa de representar o trabalho atual e passa a ser secundária. Após o primeiro pagamento `confirmed` do histórico do grupo:

- o grafo de obrigações de despesas continua sendo histórico/explicativo;
- o plano restante deve ser calculado dos saldos projetados;
- a UI não apresenta o contador de obrigações históricas como se fosse a quantidade atual de pagamentos restantes;
- a comparação de três camadas não reaparece como uma nova redução de ciclo, mesmo depois que o grupo volta a zero, porque o MVP não possui períodos formais;
- métricas de redução declaram período e denominador.

---

## 13. Contratos de teste

### 13.1 Exemplo oficial e projetado

```text
Oficial:
Ana    +6000
Bruno  -2000
Carla  -4000

Reportado:
Bruno -> Ana 1000

Projetado:
Ana    +5000
Bruno  -1000
Carla  -4000
```

Plano restante esperado:

```text
Bruno -> Ana 1000
Carla -> Ana 4000
```

### 13.2 Property tests

Para mapas aleatórios cuja soma seja zero:

- resultado zera os saldos;
- valor é conservado;
- não existem transferências inválidas;
- número de transferências não excede `m - 1`;
- executar duas vezes produz a mesma saída;
- entrada permanece inalterada.

Para pagamentos reportados aleatórios válidos:

- projeção preserva soma zero;
- sender caminha em direção a zero;
- receiver caminha em direção a zero;
- cancelar restaura a projeção anterior.

### 13.3 Testes de integração

- criar despesa recalcula oficial e projetado sem exigir uma versão antiga apenas por concorrência append-only;
- corrigir despesa anula e substitui, preservando histórico e reports;
- reportar não altera oficial, mas altera projetado;
- plano não repete valor reportado;
- confirmar altera oficial uma vez e remove a pendência;
- cancelar restaura o plano restante;
- versão obsoleta não grava ação inválida;
- duas ações concorrentes respeitam o limite sugerido;
- report pendente permanece após nova despesa e é mostrado separadamente se a direção líquida mudar;
- reutilizar idempotency key com payload diferente falha;
- convite aceito cria ou reativa um único membership;
- grupo aberto não pode ser arquivado;
- usuário de outro grupo não acessa recurso;
- despesa registrada por terceiro preserva creator e pagador e gera destaque contextual somente depois do commit;
- exemplo contraintuitivo mantém saldo correto mesmo quando a obrigação histórica e o destinatário sugerido diferem;
- reload HTTP mostra o mesmo estado lógico que a interface atualizada por stream.

---

## 14. Observabilidade mínima

- falhas de invariantes geram erro estruturado com `group_id` e versão, sem expor descrições financeiras;
- comandos registram tipo, ator, resultado e duração;
- falhas de job e broadcast são monitoradas separadamente da persistência do comando;
- métricas distinguem pagamento reportado, confirmado e cancelado;
- qualquer divergência de soma zero é tratada como erro, não arredondada silenciosamente.

---

## 15. Decisões explicitamente adiadas

- `Participant` separado de `User`;
- convidados;
- moedas e taxas de câmbio;
- integração Pix/Stripe;
- disputas, aprovação/rejeição de despesas e uso entre partes sem confiança prévia;
- solver exato em produção;
- persistência e cache de planos;
- ciclos formais de quitação;
- reversão vinculada de pagamento confirmado;
- contestação formal de despesa;
- API e webhooks externos;
- modo alternativo de acerto direto que preserve relações históricas em vez de minimizar transferências.
- suporte a múltiplos idiomas: locale é uma preocupação de apresentação e não modifica fórmulas, sinais, armazenamento monetário ou a moeda do grupo.
