# Quitando — UI/UX e Fluxos de Interação

Complemento à especificação e ao documento de domínio. O foco é tornar claras as diferenças entre despesa, saldo oficial, pagamento pendente, saldo projetado e pagamento confirmado.

Consulte também o [índice da documentação](./00-index.md).

## Navegação rápida

- [1. Princípios de UX](#1-princípios-de-ux)
- [2. Contextos que orientam a UX](#2-contextos-que-orientam-a-ux)
- [3. Mapa de telas do MVP](#3-mapa-de-telas-do-mvp)
- [4. Vocabulário da interface](#4-vocabulário-da-interface)
- [5. Lista de grupos](#5-lista-de-grupos)
- [6. Dashboard do grupo](#6-dashboard-do-grupo)
- [7. Adicionar despesa](#7-adicionar-despesa)
- [8. Plano de quitação](#8-plano-de-quitação)
- [9. Registrar pagamento](#9-registrar-pagamento)
- [10. Confirmar ou cancelar pagamento](#10-confirmar-ou-cancelar-pagamento)
- [11. Corrigir despesa](#11-corrigir-despesa)
- [12. Histórico](#12-histórico)
- [13. Configurações, convites e memberships](#13-configurações-convites-e-memberships)
- [14. Estados vazios, erros e carregamento](#14-estados-vazios-erros-e-carregamento)
- [15. Padrões Hotwire](#15-padrões-hotwire)
- [16. Mobile e desktop](#16-mobile-e-desktop)
- [17. Acessibilidade](#17-acessibilidade)
- [18. Microinterações](#18-microinterações)
- [19. Internacionalização pós-MVP](#19-internacionalização-pós-mvp)

---


## 1. Princípios de UX

- **Confiança acima de tudo.** Todo valor indica origem, estado e efeito.
- **Linguagem precisa.** “Você deve ao grupo” é saldo; “pague para Ana” é sugestão; “aguardando Ana confirmar” é pendência.
- **Explicar o destinatário, não presumir dívida bilateral.** O plano pode indicar alguém diferente do pagador de uma despesa lembrada; a interface mostra que a sugestão compensa o saldo do grupo inteiro.
- **Confiança pré-existente e transparência interna.** O MVP serve a grupos que já se conhecem; quando alguém registra em nome de outro pagador, autoria e pagador nunca são confundidos.
- **Estado oficial e projeção não se confundem.** A interface mostra o que já foi confirmado e o que acontecerá se as pendências forem aceitas.
- **Feedback imediato, com reconciliação por HTTP.** Streams atualizam conectados; reload sempre recupera o estado correto.
- **Encerramento acima do simples registro.** A UX conduz o grupo até saldo oficial zero e nenhuma pendência.
- **Lista antes do grafo.** A lista textual executa a tarefa; o grafo ajuda a entender e demonstrar.
- **Mobile-first e acessível.** Registro e quitação funcionam com poucos toques, conexão instável e sem depender de cor ou animação.

---

## 2. Contextos que orientam a UX

A interface deve funcionar especialmente bem:

- durante viagem, para registrar gasto rapidamente;
- no fechamento de evento, para descobrir o que ainda falta;
- no fim do mês de casa compartilhada, para quitar o ciclo sem planilha;
- após compra coletiva, para acompanhar quem enviou sua parte;
- ao receber transferência, para confirmar sem procurar a despesa original;
- quando o plano parecer inesperado, para explicar sem exigir teoria dos grafos.

Duas prioridades coexistem:

1. registrar precisa ser rápido e tolerante a interrupções;
2. encerrar precisa ser explícito, confiável e orientado a ações.

---

## 3. Mapa de telas do MVP

```text
Login/Cadastro
   ├── Convites Recebidos
   └── Lista de Grupos
         └── Dashboard do Grupo
               ├── Adicionar Despesa
               ├── Histórico
               ├── Plano de Quitação
               ├── Registrar Pagamento
               ├── Confirmar ou Cancelar Pendência
               └── Configurações do Grupo
```

Links públicos, participantes sem conta, disputas e pagamentos integrados ficam fora do MVP. Convites internos para contas já cadastradas fazem parte do fluxo essencial.

---

## 4. Vocabulário da interface

| Conceito | Texto recomendado |
|---|---|
| Saldo oficial negativo | “Você deve R$ X ao grupo” |
| Saldo oficial positivo | “Você tem R$ X a receber do grupo” |
| Pagamento reportado enviado | “Aguardando confirmação de Ana” |
| Saldo projetado | “Se as pendências forem confirmadas, ainda faltarão R$ X” |
| Transferência sugerida | “Pague R$ X para Ana” |
| Destinatário não intuitivo | “Você deve ao grupo. Pagar Ana compensa outras despesas e reduz transferências.” |
| Despesa criada por terceiro | “Pago por Diego · registrado por Carla” |
| Grupo settled | “Todos estão em dia — contas encerradas” |

Evitar “dívida com Ana” quando o sistema possui apenas saldo líquido e uma sugestão atual.

---

## 5. Lista de grupos

Antes dos cards, a página apresenta convites pendentes recebidos, com ações de aceitar ou recusar. Aceitar cria ou reativa o membership; recusar encerra apenas o convite; o convite, sozinho, não concede acesso ao grupo.

Cada card apresenta:

- nome e participantes;
- situação: sem movimentação, em aberto, aguardando confirmações ou quitado;
- saldo oficial do usuário;
- indicador de pendências quando existirem.

O card não executa o `DebtSimplifier`. Ele usa saldo oficial e situação derivada.

Criar grupo pode abrir Turbo Frame modal. A navegação convencional permanece disponível caso Turbo falhe.

---

## 6. Dashboard do grupo

A tela principal apresenta:

- situação geral;
- saldo oficial do usuário;
- bloco de pagamentos aguardando confirmação;
- saldo projetado após pendências;
- resumo dos participantes;
- feed de despesas e pagamentos;
- atalhos para despesa e plano.

A lista de membros mostra saldo com o grupo, não uma dívida bilateral presumida.

### 6.1 Estados do dashboard

#### Sem movimentação

> “Este grupo ainda não tem despesas. Adicione a primeira.”

#### Em aberto

> “Você deve R$ 45 ao grupo. Veja os pagamentos sugeridos.”

#### Aguardando confirmação

> “R$ 30 aguardam confirmação. Se forem confirmados, ainda faltarão R$ 15.”

#### Quitado

> “Todos estão em dia — contas encerradas.”

### 6.2 Atualização em tempo real

Quando o estado muda:

1. servidor persiste em transação;
2. componentes são recalculados;
3. broadcast ocorre depois do commit;
4. conectados recebem Turbo Streams;
5. reload ou reconexão obtém o mesmo estado por HTTP.

Toast remoto deve explicar a origem, como “Ana confirmou um pagamento; o plano foi atualizado”.

---

## 7. Adicionar despesa

Modal no desktop e bottom sheet no mobile.

### Campos do MVP

1. valor total;
2. descrição;
3. data;
4. quem pagou;
5. participantes incluídos;
6. divisão igual ou por valor exato.

Porcentagem e partes ficam para depois.

### Comportamento

- Stimulus controla campos dinâmicos, não regras financeiras;
- servidor valida memberships, valores e soma das shares;
- preview mostra arredondamento antes da confirmação;
- erros aparecem no mesmo frame sem apagar dados;
- nova despesa é append-only e não é rejeitada apenas porque outra despesa foi criada em paralelo; o servidor serializa e revalida memberships e shares;
- correção financeira envia `expected_financial_state_version`;
- se o grupo mudou durante uma correção, a tela preserva o formulário quando seguro e solicita revisão;
- ao salvar, feed, saldos, pendências e plano são atualizados;
- se quem registrou não é o pagador, o preview e o detalhe mostram claramente “pago por [nome] · registrado por [nome]”;
- depois do commit, o pagador indicado vê um aviso contextual no dashboard/feed de que outra pessoa registrou uma despesa em seu nome; se estiver conectado, o aviso pode chegar por Turbo Stream, e o próximo reload por HTTP deve exibir o mesmo destaque;
- esse aviso é informativo e derivado da despesa, sem e-mail, push, central de notificações, aprovação ou disputa no MVP.

Deep-link em modal exige configuração explícita da navegação em frame e rota funcional em acesso direto.

---

## 8. Plano de quitação

Pergunta principal:

> **O que ainda falta fazer para encerrar as contas deste grupo?**

A ordem da tela é:

1. pagamentos aguardando confirmação;
2. lista textual de transferências ainda sugeridas;
3. saldo projetado restante;
4. comparação visual e explicação.

### 8.1 Plano acionável

O plano é calculado dos saldos projetados. Assim, uma transferência `reported` aparece como pendente e não é sugerida novamente.

Exemplo:

```text
Aguardando confirmação
Bruno enviou R$ 20 para Ana

Ainda falta
Carla paga R$ 30 para Ana
```

### 8.2 Camadas explicativas

- obrigações de despesas;
- compensação bilateral;
- plano simplificado.

Antes de pagamentos, a tela pode mostrar:

```text
12 obrigações de despesas
8 após compensação bilateral
4 transferências no plano inicial
```

Depois que a quitação começa, a tela prioriza progresso. Qualquer porcentagem histórica é rotulada como baseada somente nas despesas e não como quantidade atual restante. Sem ciclos formais, a comparação de três camadas não é reiniciada como se um novo mês fosse uma nova medição depois que já houve pagamento confirmado no grupo.

### 8.3 Grafo e alternativa acessível

- nós são participantes;
- arestas indicam a camada selecionada;
- dados vêm do servidor;
- SVG/D3 apenas desenha e interage;
- tabela “de → para → valor” contém informação equivalente;
- o grafo nunca é requisito para realizar pagamento.

### 8.4 Explicabilidade

“Como chegamos a este plano?” mostra iterações do algoritmo e critérios de desempate. É secundário para o usuário comum e central para a demonstração técnica.

Quando o destinatário sugerido não corresponde ao pagador de uma despesa que o usuário reconhece, a tela oferece primeiro uma explicação curta:

> “Você deve ao grupo, não a uma despesa isolada. Pagar Ana compensa outras despesas e evita uma transferência adicional.”

A expansão pode mostrar:

- quais obrigações históricas contribuíram para o saldo do usuário;
- por que o destinatário terminou com saldo credor;
- como o pagamento sugerido zera ou reduz o saldo;
- quantas transferências adicionais seriam necessárias em um acerto mais direto.

A interface não afirma que a sugestão representa uma dívida histórica bilateral.

---

## 9. Registrar pagamento

No MVP, o report nasce de uma sugestão atual; não existe pagamento arbitrário fora do plano.

O modal mostra:

- origem e destino;
- valor sugerido;
- campo de valor entre um centavo e o valor sugerido;
- aviso: “Isto registra uma declaração manual; o saldo oficial muda após a confirmação de quem recebe.”;
- ação “Marcar como enviado”.

### Validação de versão

Ao enviar:

- servidor bloqueia o grupo;
- compara a versão financeira;
- recalcula o plano projetado;
- aceita somente se o par e o valor ainda forem válidos.

Se o plano mudou:

> “As contas foram atualizadas por outra pessoa. Revise o novo valor antes de continuar.”

O usuário não perde contexto e recebe o plano atual. Essa validação de versão vale para o report, porque ele nasce de uma sugestão calculada; confirmar ou cancelar uma pendência existente usa transição condicional de estado, não depende de o plano continuar igual.

### Mudanças enquanto há pendência

Uma nova despesa ou correção não cancela automaticamente pagamentos já reportados. A tela mantém a pendência em bloco separado e informa que o plano restante foi recalculado. Em casos raros, a projeção pode atravessar zero e sugerir uma transferência futura em sentido oposto; a interface deve explicar os dois fatos em vez de escondê-los.

### Pagamento parcial

É permitido valor inferior ao sugerido. O restante aparece no novo plano projetado.

Valor zero, negativo ou superior à sugestão atual é rejeitado; não existe “confirmação extra” para ultrapassar esse limite no MVP.

---

## 10. Confirmar ou cancelar pagamento

### Recebedor

Vê:

- “Confirmar recebimento”;
- “Marcar como não recebido”.

Antes da confirmação, a tela reforça que o pagamento se tornará um fato terminal no MVP. Confirmar muda para `confirmed`, altera saldo oficial e recalcula projeção e plano. A reversão de uma confirmação equivocada fica para uma fase posterior e não é simulada apagando ou reabrindo o registro.

“Marcar como não recebido” cancela a declaração, registra motivo e devolve o valor ao plano restante.

### Pagador

Enquanto pendente, pode “Cancelar declaração” caso tenha informado valor ou destinatário incorreto.

### Regras visuais

- `reported`: badge amarelo “aguardando confirmação”;
- `confirmed`: badge verde acompanhado de “recebimento confirmado”;
- `cancelled`: badge neutro acompanhado do ator e motivo resumido.

Owner não confirma em nome de outro participante no MVP.

---

## 11. Corrigir despesa

Campos financeiros não são editados no lugar. Creator, pagador ou owner abre “Corrigir despesa”, informa motivo e envia uma substituta. O sistema mostra a original como anulada e liga as duas versões. Alterações puramente descritivas podem ser feitas com auditoria simples.

Se existirem pagamentos reportados ou confirmados, eles permanecem no histórico e nos cálculos; a correção recalcula os saldos sem fingir que um pagamento pertencia exclusivamente àquela despesa.

---

## 12. Histórico

Reúne despesas e pagamentos em ordem cronológica.

Cada item mostra:

- tipo;
- ator;
- valor;
- estado;
- data e hora;
- link para detalhes.

Em despesas, `registrado por` e `pago por` aparecem como campos distintos sempre que forem pessoas diferentes. O pagador consegue localizar rapidamente lançamentos registrados em seu nome.

Pagamentos reportados, confirmados e cancelados são distintos. Sugestões não aparecem como eventos históricos.

Correções de despesa aparecem como cadeia:

```text
Despesa original anulada -> motivo -> despesa substituta
```

---

## 13. Configurações, convites e memberships

- owner edita nome e convida uma conta já cadastrada informando o e-mail exato, sem autocomplete público;
- a resposta de busca não expõe uma lista de usuários e o owner pode revogar convites pendentes;
- convidado aceita ou recusa o próprio convite;
- owner só arquiva grupo `empty` ou `settled`, sem pendências ou convites abertos;
- grupo arquivado é somente leitura e pode ser restaurado pelo owner sem alterar o histórico;
- membro não pode ser inativado com saldo oficial/projetado diferente de zero ou pendência;
- membership inativo pode ser reativado pelo owner sem perder histórico;
- último owner deve transferir propriedade antes de sair;
- a UI explica por que uma ação está bloqueada, em vez de apenas ocultá-la.

---

## 14. Estados vazios, erros e carregamento

### Estados vazios

- sem despesas: “Adicione a primeira despesa”;
- sem sugestões, mas com pendências: “Agora só falta confirmar os pagamentos enviados”;
- quitado: “Todos estão em dia”;
- sem confirmações para o usuário: “Nada aguardando sua confirmação”;
- sem convites: “Você não tem convites pendentes”.

### Erros

- validações próximas ao campo;
- duplo clique não duplica ação;
- versão obsoleta produz revisão, não erro genérico;
- falha de broadcast não invalida sucesso persistido por HTTP;
- ação sem permissão retorna explicação clara.

### Solver exato futuro

```text
queued -> running -> completed
                  -> timed_out
                  -> failed
                  -> stale
```

A tela usa polling como fallback e broadcast como melhoria. `loading="lazy"` apenas adia carregamento e não substitui job.

---

## 15. Padrões Hotwire

| Interação | Ferramenta | Papel |
|---|---|---|
| Criar/corrigir despesa | Turbo Frame | Navegação parcial com fallback HTTP |
| Trocar tipo de divisão | Stimulus | Apresentação client-side |
| Atualizar saldos e plano | Turbo Streams | Substituir componentes afetados |
| Sincronizar dispositivos | Action Cable + Solid Cable | Entregar broadcasts autorizados |
| Desenhar grafo | Stimulus + SVG/D3 | Renderizar dados do servidor |
| Confirmar/cancelar | Turbo Frame + Stream | Executar comando e atualizar estado |
| Aceitar convite/reativar membership | Turbo Frame + Stream | Criar acesso e atualizar listas |
| Reconciliar reconexão | HTTP | Recuperar fonte de verdade |

---

## 16. Mobile e desktop

### Mobile

- botão fixo de adicionar despesa;
- bottom sheets;
- teclado numérico;
- pendências e lista textual antes do grafo;
- filtros pessoais que não alteram o ledger.

Não existe ação unilateral que remova o usuário de uma share. Divergência exige correção autorizada ou disputa futura.

### Desktop

- saldos, pendências e feed lado a lado;
- tabela de transferências sempre visível;
- grafo em área maior;
- painel de explicação opcional.

---

## 17. Acessibilidade

- cor sempre acompanhada de texto e ícone;
- foco gerenciado ao abrir e fechar modal;
- títulos e descrições associados;
- grafo com tabela equivalente;
- animações respeitam `prefers-reduced-motion`;
- toasts não são única confirmação;
- valores são anunciados com moeda, sinal e contexto;
- alterações remotas usam região `aria-live` sem interromper excessivamente;
- a explicação de destinatário contraintuitivo é compreensível sem depender do grafo;
- `pago por` e `registrado por` permanecem distinguíveis por texto, não apenas por posição ou cor.

---

## 18. Microinterações

- check discreto na confirmação;
- destaque temporário em saldo atualizado;
- indicador de “plano recalculado” após report, confirmação ou cancelamento;
- animação opcional entre camadas;
- contador animado acompanhado do valor final estático;
- nenhuma celebração de “quitado” antes de o saldo oficial ser zero e as pendências acabarem.

---

## 19. Internacionalização pós-MVP

Depois do MVP, a interface deve oferecer múltiplos idiomas. Textos, mensagens de erro, nomes de estados, datas, números e apresentação de valores devem respeitar o locale selecionado, preservando os termos que distinguem saldo oficial, saldo projetado, sugestão e pagamento pendente.

O locale não altera o valor persistido, a moeda do grupo nem a semântica das regras financeiras; deve ser tratado como apresentação e receber cobertura de interface antes de cada novo idioma ser disponibilizado.
