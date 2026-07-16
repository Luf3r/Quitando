# Quitando — Relatório de Verificação Documental

**Data da revisão:** 15 de julho de 2026
**Escopo:** consistência cruzada entre produto, domínio, UX, casos de uso e decisões consolidadas.

Este relatório não substitui testes automatizados nem valida a implementação. A fundação Rails já existe, mas as funcionalidades do MVP ainda serão construídas conforme o roadmap. O relatório registra o resultado de uma revisão independente da documentação e as limitações que permanecem deliberadamente fora do MVP.

## Navegação rápida

- [1. Resultado](#1-resultado)
- [2. Problemas encontrados e corrigidos nesta rodada](#2-problemas-encontrados-e-corrigidos-nesta-rodada)
- [3. Coerência confirmada](#3-coerência-confirmada)
- [4. Limitações conscientes do MVP](#4-limitações-conscientes-do-mvp)
- [5. Pontos que precisam virar testes de implementação](#5-pontos-que-precisam-virar-testes-de-implementação)
- [6. Verificação da stack](#6-verificação-da-stack)
- [7. Conclusão](#7-conclusão)

---


## 1. Resultado

Após as revisões cruzadas e a auditoria estrutural final, **não foi encontrada incongruência bloqueadora restante entre os documentos**.

A documentação agora descreve de forma compatível:

```text
despesas ativas
-> saldo oficial
-> pagamentos reportados
-> saldo projetado
-> plano restante
-> confirmações
-> saldo oficial zero e nenhuma pendência
-> grupo settled
```

As fontes normativas continuam separadas:

- produto define escopo, prioridade e promessa;
- domínio define fórmulas, estados e invariantes;
- UX define linguagem e comportamentos observáveis;
- casos de uso definem dor, hipóteses e critérios de validação;
- o índice orienta a leitura e o documento de decisões consolida regras que precisam permanecer sincronizadas.

---

## 2. Problemas encontrados e corrigidos nesta rodada

### 2.1 Formação do grupo

Antes, o MVP mencionava memberships, mas não explicava como outras pessoas entravam no grupo.

Foi definido um convite interno para contas já cadastradas:

```text
pending -> accepted
pending -> declined
pending -> revoked
pending -> expired
```

Aceitar cria ou reativa um único membership. O convite não concede acesso financeiro antes da aceitação.

### 2.2 Reentrada de membro

A constraint `unique(group_id, user_id)` impedia criar outro membership, enquanto a máquina de estados não permitia voltar de `inactive`.

Agora o mesmo registro segue:

```text
active -> inactive
inactive -> active
```

O histórico permanece ligado ao membership original.

### 2.3 Arquivamento com dívidas abertas

Arquivar um grupo aberto o tornaria somente leitura e impediria a quitação.

Agora o arquivamento é permitido somente quando o grupo está `empty` ou `settled`, sem pagamento reportado nem convite pendente. O owner pode restaurar o grupo sem alterar o ledger.

### 2.4 Correção de despesas

A regra anterior permitia “edição direta” em alguns casos, mas não explicava como a auditoria seria preservada.

Agora:

- valor, pagador e shares nunca são sobrescritos;
- correção financeira anula a despesa e cria uma substituta;
- descrição e outros campos não financeiros podem ser alterados com auditoria simples;
- pagamentos existentes permanecem fatos independentes e o plano é recalculado.

### 2.5 Pendências quando o grupo muda

Um pagamento reportado pode continuar pendente enquanto novas despesas são registradas.

Ficou explícito que:

- o report não é cancelado automaticamente;
- ele continua sendo uma declaração de transferência enviada;
- a projeção e o plano restante são recalculados;
- em casos raros, a direção líquida pode se inverter;
- a interface mostra pendência e novo plano separadamente.

### 2.6 Concorrência em novas despesas

Uma nova despesa não depende de uma sugestão calculada e não precisa ser rejeitada apenas porque outra foi criada em paralelo.

Agora:

- criação de despesa é append-only, serializada e revalidada;
- report de pagamento e correção financeira usam `expected_financial_state_version`;
- confirmação e cancelamento usam transição condicional do estado existente.

### 2.7 Idempotência

Foi acrescentado um fingerprint canônico do payload.

- mesma chave + mesmo payload: devolve o resultado anterior;
- mesma chave + payload diferente: retorna conflito;
- a chave é um UUID globalmente único.

### 2.8 Responsabilidade e autorização de despesas

Ficou definido que:

- qualquer membro ativo pode registrar uma despesa;
- o pagador pode ser outro membro ativo;
- `created_by_user_id` permanece visível;
- creator, pagador ou owner pode iniciar correção;
- disputas formais continuam fora do MVP.

### 2.9 Reversão de pagamento confirmado

Os documentos mencionavam evento compensatório sem modelá-lo.

Agora a limitação é explícita:

- `confirmed` é terminal no MVP;
- o registro nunca é apagado ou reaberto;
- reversão vinculada é uma feature posterior;
- a UX reforça a consequência antes da confirmação.

### 2.10 Comparação visual em grupos recorrentes

Sem ciclos formais, um novo mês não possui uma nova linha de base confiável.

Agora:

- desde o primeiro report, a comparação histórica deixa de representar o trabalho atual;
- depois do primeiro pagamento confirmado, a comparação de três camadas não é reiniciada como se houvesse um novo ciclo;
- o plano restante continua correto, mas métricas históricas permanecem rotuladas.

### 2.11 Dívida percebida versus destinatário do plano

Foi explicitado que obrigações históricas e transferências sugeridas respondem a perguntas diferentes. Um usuário pode lembrar que deve a Diego e receber a instrução de pagar Ana sem que exista erro contábil. A documentação agora trata isso como hipótese de aceitação, risco de explicabilidade e cenário obrigatório de UX.

### 2.12 Fronteira de confiança

Ficou explícito que o MVP é destinado a grupos de confiança pré-existente. Qualquer membro ativo pode indicar outro como pagador, mas creator e pagador são auditados separadamente, o pagador recebe destaque contextual no app e não existe aprovação ou disputa no primeiro release.

---

## 3. Coerência confirmada

### Produto e promessa

- o modo padrão simplifica, mas não promete ótimo matemático;
- o produto é apresentado como encerramento de despesas, não como demonstração de grafo;
- o ciclo do MVP termina em saldo oficial zero e nenhuma pendência.

### Dinheiro e ledger

- valores usam inteiros;
- sinais de pagamentos enviados e recebidos estão corretos;
- despesas anuladas são ignoradas sem apagar histórico;
- payments `reported` alteram somente projeção;
- payments `confirmed` alteram saldo oficial;
- soma oficial e projetada permanecem zero.

### Algoritmo

- entrada é um mapa de saldos já calculados;
- a implementação gulosa é determinística;
- a complexidade declarada pressupõe filas de prioridade;
- o limite é `m - 1`, com `m` igual aos saldos não zero;
- solver exato possui timeout, fallback e versionamento futuro.

### Interface

- saldo, sugestão, report e confirmação usam textos distintos;
- lista textual é o meio operacional principal;
- grafo possui alternativa acessível;
- HTTP reconcilia o estado; broadcasts são melhoria progressiva;
- versões obsoletas geram revisão orientada, não erro genérico.

### Segurança mínima

- acesso é validado por membership;
- Action Cable autoriza subscriptions;
- IDs não concedem acesso por si só;
- logs evitam descrições e valores desnecessários;
- convites não usam autocomplete público;
- owner não confirma pagamento por terceiros.

### Estrutura e integridade documental

- a árvore documental normativa contém 25 arquivos Markdown: quatro arquivos de orientação na raiz, oito documentos numerados e treze ADRs; `README.md` e `LICENSE.md` ficam fora dessa contagem;
- os 13 ADRs estão numerados sequencialmente, possuem status e data e aparecem no índice `00`;
- links relativos e âncoras internas foram validados;
- títulos de subseções longas foram numerados para produzir âncoras únicas e previsíveis;
- blocos de código Markdown estão balanceados;
- o ZIP contém exatamente os mesmos arquivos e bytes da árvore documental e passou no teste de integridade.

---

## 4. Limitações conscientes do MVP

Estas limitações não são contradições. Elas estão documentadas e precisam ser consideradas durante a implementação e a demonstração:

1. somente usuários já cadastrados podem ser convidados;
2. não existe reversão de pagamento confirmado;
3. não existem ciclos contábeis formais para grupos recorrentes;
4. não existem disputas ou aprovação de despesas;
5. pagamentos normais só podem nascer do plano atual;
6. não existe integração bancária nem comprovação externa;
7. cada grupo usa uma moeda única;
8. participantes sem conta ficam para uma fase posterior;
9. o solver exato não faz parte do primeiro release;
10. a comparação visual de redução tem utilidade limitada depois que a quitação começa;
11. o plano pode indicar destinatário diferente do pagador da despesa percebida;
12. registros em nome de outro pagador produzem efeito sem aprovação porque o MVP pressupõe grupos de confiança.

---

## 5. Pontos que precisam virar testes de implementação

### Ledger

- soma de shares igual ao total;
- sinais de pagamento enviados e recebidos;
- soma oficial e projetada igual a zero;
- correção por anulação e substituição;
- report preservado após nova despesa;
- projeção que atravessa zero sem perder a pendência.

### Concorrência

- reports concorrentes para a mesma sugestão;
- duas confirmações simultâneas;
- correção concorrente com report;
- idempotency key com payload igual e diferente;
- broadcasts somente depois do commit.

### Membership e convites

- criação do owner inicial;
- convite duplicado;
- aceitação, recusa, revogação e expiração;
- reativação do mesmo membership;
- saída bloqueada com saldo ou pendência;
- último owner impedido de sair;
- arquivamento bloqueado em grupo aberto.

### UX e acessibilidade

- execução completa sem grafo;
- reload HTTP após cada ação;
- foco em modais e bottom sheets;
- mensagens distintas para oficial, projetado e pendente;
- confirmação terminal compreendida pelo usuário;
- destinatário contraintuitivo compreendido e aceito após explicação;
- creator e pagador distinguíveis e destaque ao pagador emitido somente depois do commit;
- conexão interrompida durante broadcast.

---

## 6. Verificação da stack

A escolha permanece coerente para Rails 8.x:

- Solid Queue é o backend padrão de Active Job a partir do Rails 8;
- Solid Cable é um adapter oficial baseado em Active Record e testado com PostgreSQL;
- Devise mantém matriz de testes para Rails 8 e sua versão atual documenta suporte a Rails 7 em diante;
- as versões exatas devem ser fixadas no `Gemfile.lock` no início da implementação.

Referências oficiais:

- [Rails — Active Job Basics](https://guides.rubyonrails.org/active_job_basics.html)
- [Rails — Action Cable Overview](https://guides.rubyonrails.org/action_cable_overview.html)
- [Devise — repositório oficial](https://github.com/heartcombo/devise)
- [ViewComponent — repositório oficial](https://github.com/ViewComponent/view_component)

---

## 7. Conclusão

A documentação está suficientemente coerente para iniciar a implementação do MVP.

Os maiores riscos restantes não são contradições documentais, mas hipóteses de produto e execução:

- confirmação dupla pode gerar fricção;
- convite limitado a contas existentes pode dificultar adoção;
- reports pendentes podem produzir cenários visuais complexos após novas despesas;
- ausência de reversão exige cuidado especial na confirmação;
- grupos recorrentes podem demandar ciclos formais antes do previsto;
- usuários podem rejeitar o plano quando o destinatário difere da dívida percebida;
- a premissa de grupos de confiança pode ser estreita demais se registros em nome de terceiros gerarem desconforto.

A implementação deve começar pelo ledger e pelos contratos de teste, antes do grafo e das microinterações. Isso permitirá validar as regras mais arriscadas com baixo custo de retrabalho. Os cenários de destinatário contraintuitivo e despesa registrada por terceiro já fazem parte dos gates de UX e não exigem alterar o ledger.

A ordem detalhada, os arquivos de spec e os critérios de saída foram consolidados no [Roadmap de Implementação e Estratégia de Specs](./05-quitando-roadmap-implementacao.md).
