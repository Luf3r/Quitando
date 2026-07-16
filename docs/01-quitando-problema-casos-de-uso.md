# Quitando — Problema, Casos de Uso e Hipóteses de Produto

Este documento explica a dor humana, os contextos em que ela aparece, as fronteiras do produto e as hipóteses que precisam ser validadas.

Consulte também o [índice da documentação](./00-index.md).

## Navegação rápida

- [1. O problema humano](#1-o-problema-humano)
- [2. O que o produto reduz](#2-o-que-o-produto-reduz)
- [3. Jobs to be Done](#3-jobs-to-be-done)
- [4. Casos de uso do dia a dia](#4-casos-de-uso-do-dia-a-dia)
- [5. Cenário completo](#5-cenário-completo)
- [6. Quando o produto é mais útil](#6-quando-o-produto-é-mais-útil)
- [7. Segmentos e intensidade da dor](#7-segmentos-e-intensidade-da-dor)
- [8. Casos que o MVP não resolve](#8-casos-que-o-mvp-não-resolve)
- [9. Riscos de produto](#9-riscos-de-produto)
- [10. Hipóteses a validar](#10-hipóteses-a-validar)
- [11. Como validar](#11-como-validar)
- [12. Indicadores de sucesso](#12-indicadores-de-sucesso)
- [13. Narrativa recomendada](#13-narrativa-recomendada)

---


## 1. O problema humano

Dividir uma despesa isolada é simples. O problema surge quando um grupo acumula vários pagamentos feitos por pessoas diferentes, em momentos e divisões diferentes.

No encerramento, os participantes precisam responder:

- quanto cada pessoa pagou;
- quanto cabia a cada pessoa;
- quem ainda deve e quem deve receber;
- para quem transferir;
- o que já foi enviado, confirmado ou cancelado;
- o que ainda restará depois das pendências.

Planilhas e calculadoras ajudam com a aritmética, mas normalmente não oferecem, ao mesmo tempo:

- fonte de verdade compartilhada;
- histórico compreensível;
- distinção entre saldo oficial, pendência e sugestão;
- confirmação do recebedor;
- redução da quantidade de transferências;
- explicação do plano;
- indicação inequívoca de encerramento.

O Quitando transforma um histórico potencialmente confuso em um **processo de quitação claro, verificável e com baixo atrito social**.

### Formulação curta

> Grupos acumulam despesas com facilidade, mas têm dificuldade para encerrar as contas de forma simples, confiável e sem negociar cada relação separadamente.

### Proposta de valor

> O Quitando consolida despesas compartilhadas, mostra o estado confirmado e o estado projetado e gera um plano de pagamentos para que o grupo encerre as contas com menos transferências e menos ambiguidade.

---

## 2. O que o produto reduz

- **carga cognitiva:** ninguém reconstrói manualmente o histórico;
- **transferências desnecessárias:** o grupo recebe um plano consolidado;
- **erros:** shares, saldos e pagamentos seguem invariantes;
- **mensagens de cobrança:** o estado é compartilhado;
- **constrangimento social:** a pendência não depende de uma pessoa lembrar e insistir;
- **ambiguidade:** cada valor informa se é oficial, projetado, sugerido ou confirmado;
- **retrabalho:** reports são reservados na projeção e não aparecem novamente como sugestão;
- **falso encerramento:** o grupo só é considerado quitado depois das confirmações.

O algoritmo é um meio. O produto deve ser apresentado como uma ferramenta para **encerrar despesas compartilhadas com clareza**, e não apenas como “um app que usa grafos”.

---

## 3. Jobs to be Done

### Job principal

> Quando meu grupo acumular despesas pagas por pessoas diferentes, quero saber o que ainda falta e receber um plano simples, para encerrar as contas sem cálculos manuais nem negociação de cada dívida.

### Jobs complementares

- Quando eu pagar algo, quero registrar rapidamente os participantes.
- Quando eu estiver devendo, quero ver quanto devo ao grupo e quais transferências são sugeridas.
- Quando eu declarar um pagamento, quero que ele deixe de ser sugerido enquanto aguarda confirmação.
- Quando alguém disser que me pagou, quero confirmar ou indicar que não recebi.
- Quando houver pendências, quero saber o que é oficial e o que é apenas projetado.
- Quando o plano mudar, quero entender por quê.
- Quando o grupo terminar uma viagem, evento ou mês, quero saber que o encerramento está completo.

---

## 4. Casos de uso do dia a dia

### 4.1 Viagem entre amigos

Pessoas diferentes pagam hospedagem, combustível, pedágio, refeições, ingressos e transporte. Algumas despesas incluem todos; outras, apenas parte do grupo.

**Dor:** ninguém quer reconstruir dias de gastos no WhatsApp nem fazer vários PIX sem saber se o total fecha.

### 4.2 República ou apartamento compartilhado

Moradores dividem aluguel, internet, energia, água, mercado e limpeza. O grupo pode chegar a zero ao fim do mês e continuar usando o mesmo ledger no período seguinte.

**Dor:** diferenças pequenas se acumulam e quem adianta dinheiro vira também cobrador.

**Limite do MVP:** não existe fechamento formal por competência; cada “mês quitado” é um momento em que o saldo chega a zero. Ciclos formais ficam para uma fase posterior.

### 4.3 Churrasco, festa ou jantar

Uma pessoa compra comida, outra bebidas, outra gelo e outra transporte ou local.

**Dor:** o valor pode ser pequeno, mas coordenar muitas mensagens e transferências custa mais que fazer a divisão.

### 4.4 Casal com despesas divididas

Casais podem dividir alimentação, transporte, assinaturas, viagens e compras domésticas sem usar conta conjunta para tudo.

**Dor:** pequenos pagamentos geram uma prestação de contas cansativa.

O produto não deve virar ferramenta de vigilância. O foco são despesas declaradamente compartilhadas, não gastos pessoais.

### 4.5 Evento, equipe ou projeto temporário

Hackathons, bandas, equipes esportivas, grupos de estudo e produções independentes envolvem adiantamentos por participantes diferentes.

**Dor:** o grupo temporário não quer criar processo financeiro pesado para custos pontuais.

### 4.6 Atividade familiar

Familiares dividem hospedagem, refeições, transporte ou compras de comemoração.

**Dor:** cobrar individualmente é desconfortável quando as regras não foram registradas no momento do gasto.

### 4.7 Compra coletiva

Uma pessoa adianta o valor para obter frete grátis, desconto por volume ou compartilhar serviço.

**Dor:** o organizador precisa acompanhar quem enviou, quem ainda deve e quanto falta.

### 4.8 Caronas e deslocamentos recorrentes

Um grupo alterna combustível, estacionamento e pedágios, acumulando valores por um período.

**Dor:** acertar cada trajeto gera mais trabalho que o valor envolvido.

---

## 5. Cenário completo

Quatro pessoas fazem uma viagem. Após registrar despesas e shares, os saldos oficiais são:

```text
Ana:   +R$ 420
Bruno: -R$ 100
Carla: -R$ 120
Diego: -R$ 200
```

Plano inicial:

```text
Bruno paga R$ 100 para Ana
Carla paga R$ 120 para Ana
Diego paga R$ 200 para Ana
```

Bruno reporta R$ 100 para Ana. Antes da confirmação:

```text
Saldo oficial de Bruno:  -R$ 100
Saldo projetado de Bruno: R$   0
Pendência: aguardando Ana confirmar R$ 100
```

O plano restante não sugere novamente o pagamento de Bruno:

```text
Carla paga R$ 120 para Ana
Diego paga R$ 200 para Ana
```

Quando Ana confirma, o saldo oficial de Bruno chega a zero. O grupo só fica quitado depois que os três pagamentos forem confirmados e não houver outras pendências.

```text
despesas -> saldos oficiais -> projeção -> plano restante -> confirmações -> grupo quitado
```

---

## 6. Quando o produto é mais útil

- três ou mais participantes;
- vários pagadores;
- muitas despesas ao longo de um período;
- despesas que não incluem todos;
- desejo de reduzir transferências;
- necessidade de distinguir enviado de recebido;
- custo social da cobrança maior que o custo matemático da divisão.

Para uma única conta igual entre duas pessoas, calculadora ou PIX dividido pode ser suficiente.

---

## 7. Segmentos e intensidade da dor

| Contexto | Frequência | Complexidade | Valor provável |
|---|---:|---:|---:|
| Viagem em grupo | episódica | alta | alto |
| República | recorrente | alta | alto |
| Evento pontual | episódica | média | médio/alto |
| Compra coletiva | pontual | média | médio |
| Casal | recorrente | baixa/média | depende do hábito |
| Carona | recorrente | baixa/média | médio |

Para validação inicial, viagens e repúblicas são segmentos prioritários: possuem muitas despesas, pagadores diferentes e um momento de encerramento reconhecível.

---

## 8. Casos que o MVP não resolve

- contabilidade empresarial;
- folha de pagamento;
- crédito, empréstimo ou juros;
- orçamento pessoal completo;
- transferência bancária real;
- conversão cambial;
- pessoas sem conta como participantes;
- convite por link para quem ainda não possui cadastro;
- disputa legal;
- comprovação bancária;
- pagamento para par fora do plano atual;
- reversão de pagamento já confirmado;
- fechamento contábil formal por período.

O sistema organiza declarações e confirmações em grupos de confiança. Não substitui banco, contrato ou sistema contábil.

### Premissa de confiança do MVP

O produto é desenhado para pessoas que já possuem uma relação fora do aplicativo. Qualquer membro ativo pode registrar uma despesa e indicar outro membro ativo como pagador, o que favorece reconstruções colaborativas e reduz fricção, mas pressupõe boa-fé. A autoria do registro, o pagador indicado e todas as correções devem permanecer visíveis.

O MVP não é adequado para desconhecidos, marketplaces, relações contratuais sensíveis ou grupos em que um lançamento precisa ser aprovado antes de produzir efeito financeiro. Disputas, aprovação de despesa e comprovação externa são features posteriores.

---

## 9. Riscos de produto

### Registro trabalhoso

Se o formulário exigir demais, o grupo deixa para depois e os dados perdem qualidade.

### Destinatário contraintuitivo

Uma sugestão pode mandar Carla pagar Ana mesmo que Carla associe sua dívida a Diego, que pagou uma despesa específica. O resultado pode estar matematicamente correto e ainda parecer socialmente errado. O produto precisa explicar que obrigações históricas mostram como o saldo surgiu, enquanto o plano líquido escolhe como o grupo será quitado com menos transferências. Se essa explicação não for suficiente nos testes, uma fase posterior pode avaliar um modo opcional de acerto direto, com mais transferências e maior proximidade das relações históricas.

### Registro em nome de outro pagador

Permitir que qualquer membro ativo registre uma despesa indicando outro pagador facilita viagens e reconstruções posteriores, mas pode gerar erro ou abuso fora de grupos de confiança. O produto precisa mostrar `registrado por` e `pago por`, destacar o lançamento para o pagador indicado no próprio aplicativo e manter correções auditáveis.

### Falta de confiança

Uma sugestão inesperada ou um registro feito por outra pessoa pode parecer errado. O produto precisa mostrar histórico, autoria, sinais, pendências e explicação.

### Confirmação dupla

Pode aumentar confiança ou adicionar fricção. É hipótese a validar, não verdade assumida.

### Pendência esquecida

Sem lembrete ou destaque, um report pode ficar aguardando indefinidamente. O MVP precisa tornar pendências visíveis; notificações automáticas podem vir depois.

### Mudança depois do report

Novas despesas podem alterar o plano enquanto uma transferência aguarda confirmação. O produto precisa manter o report como declaração separada e explicar recalculos, inclusive quando a direção líquida mudar.

### Confirmação equivocada

Um pagamento confirmado é terminal no MVP. A interface deve tornar a consequência explícita e a validação precisa medir se a ausência de reversão gera erros suficientes para antecipar essa feature.

### Entrada no grupo

Sem um convite simples, o produto falha antes do primeiro gasto. O MVP usa convites internos para contas existentes; é preciso validar se essa restrição é aceitável no piloto.

### Redução pequena

Nem todo grupo terá resultado impressionante. Comunicação não promete porcentagem fixa.

### Comparação enganosa

Obrigações de despesas e plano restante não são a mesma medida depois que pagamentos começam. Métricas precisam informar período e denominador.

### Concorrentes

A ideia não precisa ser inédita. O diferencial de portfólio é execução rigorosa, explicabilidade, consistência e arquitetura Rails/Hotwire.

---

## 10. Hipóteses a validar

1. Encerrar contas é uma dor maior que apenas registrar despesas.
2. Instruções “quem paga quem” são mais úteis que somente saldo.
3. Reduzir transferências é percebido como valor.
4. Confirmação pelo recebedor aumenta confiança mais do que fricção.
5. Report pendente precisa reservar valor no plano para evitar dupla ação.
6. Lista textual é mais útil que grafo para executar pagamentos.
7. Explicação é necessária quando o resultado parece contraintuitivo.
8. Registro precisa ser rápido o suficiente para uso no momento da despesa.
9. Pagamentos parciais acontecem com frequência suficiente para justificar a complexidade.
10. Grupos recorrentes toleram ausência de ciclos formais no MVP.
11. Convidar somente usuários já cadastrados é suficiente para o primeiro release.
12. Usuários entendem que uma confirmação é terminal enquanto reversões não existem.
13. Usuários aceitam pagar a pessoa indicada pelo plano líquido, mesmo quando ela não corresponde a quem pagou a despesa que originou sua percepção de dívida.
14. Grupos de confiança aceitam que um membro registre uma despesa indicando outro membro como pagador, desde que autoria, aviso e correções sejam transparentes.

---

## 11. Como validar

### Entrevistas

- Como registraram os gastos?
- Quando fizeram o acerto?
- O que deu mais trabalho?
- Quantas transferências ocorreram?
- Quem precisou cobrar?
- Houve dúvida sobre algo já pago?
- Um pagamento enviado precisou ser confirmado?
- O que faria abandonar o app?
- Você aceitaria pagar alguém diferente de quem pagou a despesa que você lembra? O que precisaria ser explicado?
- Como se sentiria se outro membro registrasse uma despesa dizendo que você foi o pagador?

### Teste de protótipo

Pedir que a pessoa:

1. descubra saldo oficial;
2. identifique para quem pagar;
3. reporte pagamento;
4. explique a diferença entre oficial e projetado;
5. confirme recebimento;
6. identifique quando o grupo está quitado;
7. aceite um convite e entenda quando o acesso começa;
8. explique o que faria ao confirmar um pagamento por engano;
9. interprete um caso em que o destinatário sugerido não é o pagador da despesa lembrada;
10. identifique quem registrou e quem pagou uma despesa lançada por outra pessoa.

### Teste de falsificação

A hipótese central enfraquece se usuários:

- preferirem acertar tudo diretamente por mensagem;
- não valorizarem redução de transferências;
- considerarem confirmação dupla irritante demais;
- não entenderem oficial versus projetado após protótipo orientado;
- abandonarem o registro por excesso de passos;
- não conseguirem formar o grupo por causa do convite restrito a contas existentes;
- confirmarem pagamentos por engano com frequência relevante;
- recusarem o plano quando o destinatário difere da dívida percebida, mesmo após uma explicação curta;
- considerarem inaceitável que outro membro registre uma despesa em seu nome, mesmo com autoria e aviso transparentes.

### Piloto real

Usar em ao menos:

- uma viagem com quatro ou mais pessoas;
- um grupo recorrente por um mês;
- um evento pontual.

Registrar correções, abandonos, tempo até quitação e mensagens paralelas necessárias.

---

## 12. Indicadores de sucesso

- porcentagem de grupos com atividade que chegam a `settled`;
- tempo entre última despesa e quitação;
- reports confirmados, cancelados e esquecidos;
- quantidade de transferências sugeridas no plano inicial;
- redução com denominador explicitado;
- taxa de conclusão do formulário;
- ações rejeitadas por versão obsoleta;
- convites enviados, aceitos, recusados, revogados e expirados;
- tentativas de arquivar ou sair bloqueadas por invariantes;
- consultas à explicação;
- relatos de redução de mensagens e cobranças;
- taxa de compreensão e aceitação de destinatários contraintuitivos;
- correções ou rejeições informais de despesas registradas por alguém diferente do pagador.

Métricas de obrigação versus plano devem informar:

- período analisado;
- se pagamentos já haviam começado;
- camada usada como base.

O sucesso principal é **quantos grupos encerram contas com clareza**, não quantas despesas são cadastradas.

---

## 13. Narrativa recomendada

### Produto

> Durante viagens, eventos e rotinas compartilhadas, pessoas diferentes pagam despesas diferentes. No final, o grupo precisa reconstruir quem deve quanto e coordenar transferências. O Quitando consolida o histórico, distingue o que está confirmado do que ainda está pendente e entrega um plano claro até as contas serem encerradas.

### Técnica

> A aplicação mantém um ledger oficial, projeta pagamentos pendentes separadamente e aplica um algoritmo guloso determinístico aos saldos projetados. Comandos financeiros são versionados, idempotentes e revalidados sob concorrência. Rails e Hotwire entregam uma UI reativa com HTTP como fonte de reconciliação.

### Frase curta

> Menos contas para reconstruir, menos transferências para coordenar e mais clareza para encerrar as dívidas do grupo.
