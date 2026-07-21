# Quitando — Contexto do Projeto

Este arquivo é a porta de entrada compacta para desenvolvedores e agentes de código. Ele resume o projeto, mas **não substitui os documentos normativos**.

Para regras operacionais de desenvolvimento, leia [`AGENTS.md`](./AGENTS.md). Para decisões detalhadas, siga a ordem indicada em [`docs/00-index.md`](./docs/00-index.md).

A execução do roadmap é acompanhada no [GitHub Project — Quitando](https://github.com/users/Luf3r/projects/2). O quadro registra tarefas, dependências e progresso, mas não substitui as fontes normativas do repositório.

---

## 1. Missão do produto

O Quitando ajuda grupos com confiança pré-existente a transformar um histórico de despesas compartilhadas em um processo de quitação claro e verificável.

O produto não termina no cadastro da despesa. O fluxo central é:

```text
despesas ativas
-> saldo oficial
-> pagamentos reportados
-> saldo projetado
-> plano restante
-> confirmações
-> saldo oficial zero e nenhuma pendência
-> grupo quitado
```

A proposta principal é reduzir:

- reconstrução manual de contas;
- transferências desnecessárias;
- mensagens de cobrança;
- ambiguidade entre o que foi sugerido, enviado e confirmado;
- atrito social para encerrar as despesas do grupo.

---

## 2. Fronteira de confiança

O MVP atende amigos, familiares, casais, colegas de casa e equipes pequenas que já possuem uma relação de confiança fora do aplicativo.

Qualquer membro ativo pode registrar uma despesa e indicar outro membro ativo como pagador. Por isso:

- `created_by_user_id` e `paid_by_user_id` são fatos diferentes;
- autoria e pagador devem permanecer visíveis e auditáveis;
- o pagador indicado recebe destaque contextual no aplicativo;
- a despesa produz efeito sem aprovação prévia no MVP;
- contestação, rejeição e proteção contra participantes mal-intencionados estão fora do MVP.

O produto não deve ser apresentado como banco, prova jurídica, sistema contábil ou plataforma para desconhecidos.

---

## 3. Conceitos que nunca devem ser confundidos

- **Obrigação de despesa:** relação histórica criada por uma share de não pagador.
- **Saldo oficial:** posição líquida calculada com despesas ativas, shares e pagamentos `confirmed`.
- **Pagamento `reported`:** declaração pendente de que uma transferência foi enviada.
- **Saldo projetado:** saldo oficial ajustado pelos pagamentos `reported`.
- **Plano de quitação:** sugestões temporárias calculadas sobre o saldo projetado.
- **Pagamento `confirmed`:** fato aceito pelo recebedor e incorporado ao ledger oficial.
- **Dívida percebida:** pessoa a quem o usuário sente que deve por causa de uma despesa lembrada.

O destinatário do plano pode ser diferente da pessoa associada à dívida percebida. Isso não é erro contábil: o algoritmo opera sobre saldos líquidos do grupo.

---

## 4. Promessa algorítmica

O modo padrão usa uma simplificação gulosa determinística:

- recebe saldos cuja soma é zero;
- recebe participantes identificados por strings UUID v7 canônicas;
- casa o maior devedor com o maior credor;
- desempata magnitudes iguais por UUID crescente em ordem lexicográfica;
- gera no máximo `m - 1` transferências, com `m` igual à quantidade de saldos não zero;
- com filas de prioridade, opera em `O(m log m)`;
- não promete o menor número matematicamente possível em todos os casos.

O solver exato é uma fase posterior e deve possuir orçamento de execução, timeout, fallback e versionamento.

---

## 5. Escopo do MVP

O primeiro release inclui:

1. autenticação;
2. grupos e owner inicial;
3. convites internos para usuários já cadastrados;
4. memberships ativos/inativos com reativação do mesmo registro;
5. despesas divididas igualmente ou por valor exato;
6. ledger e saldo oficial;
7. saldo projetado por pagamentos pendentes;
8. plano guloso determinístico;
9. pagamento parcial ou total a partir de sugestão atual;
10. confirmação ou cancelamento do pagamento reportado;
11. correção financeira de despesa por anulação e substituição;
12. histórico auditável;
13. HTML funcional com autorização;
14. Turbo/Action Cable como melhoria progressiva;
15. lista textual operacional e grafo complementar acessível;
16. observabilidade mínima e deploy.

---

## 6. Fora do MVP

Não implementar implicitamente:

- participantes sem conta;
- convite ou cobrança por link público;
- multi-moeda;
- Pix, Stripe ou comprovação bancária;
- reversão de pagamento confirmado;
- disputas ou aprovação de despesas;
- pagamento arbitrário fora do plano atual;
- ciclos contábeis formais;
- despesas recorrentes automáticas;
- solver exato em produção;
- API pública e webhooks externos;
- persistência ou cache do plano;
- modo de acerto direto que preserve relações históricas;
- e-mail, push ou central persistente de notificações.

Após o MVP, o suporte a múltiplos idiomas é um objetivo do produto. Ele deve localizar a interface e a apresentação de datas, números e valores, sem alterar o ledger, que continua a usar inteiros na menor unidade da moeda; isso não introduz multi-moeda.

---

## 7. Arquitetura de domínio

Serviços principais:

```text
GroupBalanceCalculator
  despesas ativas + shares + payments confirmed
  -> saldos oficiais

ProjectedBalanceCalculator
  saldos oficiais + payments reported
  -> saldos projetados

DebtSimplifier
  saldos projetados
  -> transferências sugeridas

ObligationGraphBuilder
  despesas e shares
  -> obrigações históricas e compensação bilateral

PaymentReporter / PaymentConfirmer / PaymentCanceller
  -> workflow, autorização, versão, idempotência e concorrência

GroupFinancialStatusResolver
  -> empty | open | awaiting_confirmation | settled
```

Princípio central:

> Fatos financeiros são persistidos; projeções e sugestões são recalculáveis.

O plano de quitação não é persistido no MVP.

---

## 8. Regras financeiras resumidas

Para cada usuário:

```text
saldo_oficial = total_pago_em_despesas
              - total_das_proprias_shares
              + pagamentos_confirmados_enviados
              - pagamentos_confirmados_recebidos
```

```text
saldo_projetado = saldo_oficial
                 + pagamentos_reportados_enviados
                 - pagamentos_reportados_recebidos
```

Invariantes essenciais:

- dinheiro usa inteiros na menor unidade da moeda;
- nunca usar `float` para dinheiro;
- soma das shares = valor da despesa;
- soma dos saldos oficiais = zero;
- soma dos saldos projetados = zero;
- somente `confirmed` altera saldo oficial;
- `reported` altera somente projeção e plano restante;
- sugestões não são pagamentos;
- fatos confirmados não são apagados ou reabertos silenciosamente.

---

## 9. Estados principais

### Pagamento

```text
reported -> confirmed
reported -> cancelled
```

`confirmed` e `cancelled` são terminais no MVP.

### Membership

```text
active -> inactive
inactive -> active
```

### Convite

```text
pending -> accepted
pending -> declined
pending -> revoked
pending -> expired
```

### Situação financeira do grupo

```text
empty
open
awaiting_confirmation
settled
```

Arquivamento é uma condição operacional separada. Só é permitido para grupo `empty` ou `settled`, sem pagamento `reported` ou convite pendente.

---

## 10. Consistência e concorrência

- mudanças financeiras são serializadas por grupo;
- toda mudança financeiramente material incrementa `financial_state_version`;
- reports e correções financeiras recebem `expected_financial_state_version`;
- criar uma despesa append-only é serializado e revalidado, mas não falha apenas por versão concorrente;
- operações sensíveis usam idempotency key e fingerprint canônico;
- mesma chave + mesmo payload retorna o resultado anterior;
- mesma chave + payload diferente gera conflito;
- broadcasts acontecem somente depois do commit;
- HTTP permanece a fonte de reconciliação.

---

## 11. Milestone atual

- **Fase atual:** Fase 2 — Schema e entidades financeiras mínimas
- **Status atual:** Fases 0 e 1 concluídas; a Fase 2 está em andamento e seu gate estrutural está em verificação
- **Próxima fase:** Fase 2 — Schema e entidades financeiras mínimas
- **Trabalho executável atual:** issue [#32 — Persistir Group com UUID v7 e versão financeira](https://github.com/Luf3r/Quitando/issues/32) em `In progress`; as demais subissues aguardam suas dependências no GitHub Project
- **Gate concluído da Fase 0:** repositório executa `bin/ci` localmente e no CI remoto, com banco limpo, contrato idêntico e exemplos RSpec reais para os contratos da fundação.

**Implementado e verificado até agora:**

- aplicação Rails com Ruby e dependências fixadas;
- PostgreSQL 18 padronizado no Docker local e no CI;
- infraestrutura RSpec carregando o ambiente Rails;
- `bin/ci` com lint, auditorias de dependências e segurança, eager load, RSpec e seeds;
- configuração de desenvolvimento Docker, Active Storage e locale padrão `pt-BR`.
- FactoryBot integrado ao RSpec, factory inicial de `User`, Devise e Pundit configurados;
- PK inicial de `User` em UUID v7 gerado pelo PostgreSQL 18, com generators Rails preparados para PKs UUID;
- `DebtSimplifier` Ruby puro, determinístico e guloso, com UUID v7 canônica, erros tipados e transferências em `O(m log m)`;
- exemplos, property tests com seed/shrinking e subprocesso de isolamento cobrindo o gate da Fase 1;
- parser monetário `pt-BR` para centavos sem `float`;
- specs reais de boot, health check, autenticação, parser, factory e processamento Vips;
- imagem de produção sem gems dos grupos `development` e `test`.
- GitHub Actions `CI` executando `bin/ci` no commit `f18479c` com conclusão `success` em 16 de julho de 2026.
- `Group`, `Membership`, `Expense`, `ExpenseShare` e `Payment` em implementação na worktree da Fase 2, com PK UUID v7, FKs UUID, dinheiro em `bigint`, índices e checks estruturais ainda sujeitos ao gate final.

**Pendente antes de avançar no produto:**

- definir limite superior, overflow e mensagem do parser monetário quando ele alimentar colunas `bigint` nas fases de despesas e constraints;
- avaliar uma spec de Active Storage variant real quando attachments entrarem no domínio, além da prova atual de processamento com `ruby-vips`.
- concluir as subissues #32–#37, registrar evidências e demonstrar o gate da Fase 2 antes de promover a Fase 3.

Atualize esta seção e o [GitHub Project](https://github.com/users/Luf3r/projects/2) sempre que a tarefa ativa, uma entrega verificável, pendência, fase ou gate mudar. O estado detalhado e os critérios de saída ficam no [roadmap de implementação](./docs/05-quitando-roadmap-implementacao.md).

---

## 12. Ordem técnica resumida

A implementação segue risco e dependências, não a ordem das telas:

```text
fundação e CI
-> DebtSimplifier puro
-> schema e constraints
-> criação de despesas e arredondamento
-> saldo oficial
-> primeiro plano
-> saldo projetado
-> workflow de pagamentos
-> situação do grupo
-> correção imutável de despesas
-> convites e memberships
-> requests, policies e HTML
-> Turbo Streams e Action Cable
-> grafo, explicação e acessibilidade
-> hardening, observabilidade e deploy
```

Detalhes, specs e gates estão em [`docs/05-quitando-roadmap-implementacao.md`](./docs/05-quitando-roadmap-implementacao.md).

---

## 13. Stack planejada

- Rails 8.x;
- PostgreSQL 18;
- RSpec;
- Devise;
- Pundit;
- Turbo + Stimulus;
- Action Cable + Solid Cable;
- Active Job + Solid Queue;
- ViewComponent + Tailwind CSS;
- Kamal.

Versões exatas devem ser fixadas no início da implementação, na configuração executável e no lockfile quando aplicável.

---

## 14. Fontes normativas

Em caso de divergência:

- [`docs/03-quitando-domain-architecture.md`](./docs/03-quitando-domain-architecture.md): fórmulas, invariantes, estados e contratos técnicos;
- [`projeto-quitando.md`](./docs/02-projeto-quitando.md): escopo, prioridade e promessa do produto;
- [`docs/05-quitando-roadmap-implementacao.md`](./docs/05-quitando-roadmap-implementacao.md): ordem de construção, specs e gates;
- [`quitando-ux-ui.md`](./docs/04-quitando-ux-ui.md): linguagem e comportamento visual;
- [`quitando-problema-casos-de-uso.md`](./docs/01-quitando-problema-casos-de-uso.md): dor, casos de uso e hipóteses;
- [`docs/00-index.md`](./docs/00-index.md): índice, ordem de leitura e precedência;
- [`docs/07-quitando-decisoes-consolidadas.md`](./docs/07-quitando-decisoes-consolidadas.md): resumo das decisões vigentes;
- [`docs/adr/`](./docs/adr/): contexto e consequências das decisões arquiteturais.
