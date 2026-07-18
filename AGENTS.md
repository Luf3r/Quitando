# AGENTS.md — Quitando

Estas instruções orientam qualquer agente de código que trabalhe neste repositório. Elas são operacionais e obrigatórias. Não duplicam todas as justificativas dos documentos de projeto.

---

## 1. Antes de modificar código

Leia, nesta ordem:

1. [`PROJECT.md`](./PROJECT.md);
2. este arquivo;
3. [`docs/00-index.md`](./docs/00-index.md);
4. a fase atual em [`docs/05-quitando-roadmap-implementacao.md`](./docs/05-quitando-roadmap-implementacao.md);
5. as seções relevantes de [`docs/03-quitando-domain-architecture.md`](./docs/03-quitando-domain-architecture.md);
6. UX, produto ou casos de uso quando a tarefa afetar esses assuntos.
7. a issue ou subissue correspondente no [GitHub Project — Quitando](https://github.com/users/Luf3r/projects/2), incluindo dependências, campos e status.

Antes de implementar:

- inspecione o código e as specs existentes;
- identifique a fase e o gate do roadmap;
- confirme que a tarefa executável está em `Ready`, não possui dependência aberta e tem contrato compatível com as fontes normativas;
- liste contratos afetados;
- registre o contrato da tarefa definido na seção 7.1;
- classifique o impacto documental conforme a seção 12.1;
- não presuma que uma regra comum de outros apps se aplica aqui.
- não invente uma regra financeira para preencher ambiguidade; registre a incerteza e não altere o comportamento normativo sem decisão explícita.
- consulte o ADR relacionado antes de mudar uma decisão arquitetural aceita.

---

## 2. Hierarquia de fontes

Em caso de conflito:

1. **Domínio e arquitetura** prevalecem para fórmulas, invariantes, estados e consistência.
2. **Especificação do produto** prevalece para escopo e prioridade.
3. **Roadmap técnico** prevalece para ordem de construção, specs e gates.
4. **UX/UI** prevalece para linguagem e comportamento observável.
5. **Problema e casos de uso** prevalecem para hipóteses e alegações de valor.
6. **Decisões consolidadas** em [`docs/07-quitando-decisoes-consolidadas.md`](./docs/07-quitando-decisoes-consolidadas.md) resumem as regras vigentes e devem permanecer sincronizadas.
7. **ADRs aceitos** explicam decisões arquiteturais; mudanças materiais exigem um ADR que supersede o anterior.

Não resolva divergências silenciosamente. Corrija os documentos afetados junto com o código ou registre claramente o bloqueio.

---

## 3. Nunca faça

- nunca use `float` para dinheiro;
- nunca atualize saldos persistidos manualmente como fonte de verdade;
- nunca trate sugestão como pagamento;
- nunca sobrescreva campos financeiros históricos;
- nunca confirme ou cancele em nome de ator não autorizado;
- nunca publique broadcast antes do commit;
- nunca pule specs para uma regra financeira;
- nunca implemente item fora do MVP por conveniência;
- nunca altere uma decisão aceita reescrevendo um ADR antigo: crie um ADR que o substitua.
- nunca substitua silenciosamente o comportamento principal solicitado por fallback, `no-op`, mock, stub, valor padrão ou recuperação genérica para obter testes verdes ou concluir a tarefa.

---

## 4. Regras de domínio não negociáveis

### Dinheiro

- Use inteiros na menor unidade da moeda, normalmente centavos.
- Colunas monetárias usam `bigint`, salvo decisão documentada em contrário.
- Nunca use `float` para parsing, cálculo, persistência ou comparação monetária.
- Converta entrada decimal localizada diretamente para inteiro.
- A soma das shares deve ser exatamente igual ao valor da despesa.
- Arredondamento deve ser determinístico, reproduzível e testado.

### Ledger

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

- A soma dos saldos oficiais deve ser zero.
- A soma dos saldos projetados deve ser zero.
- Somente `Payment.confirmed` altera o saldo oficial.
- `Payment.reported` altera apenas projeção e plano restante.
- Cancelar um `reported` remove seu efeito projetado.
- Um report existente não é cancelado automaticamente quando uma nova despesa muda o plano.

### Plano de quitação

- `DebtSimplifier` recebe saldos prontos; ele não calcula o ledger.
- O plano acionável usa saldos projetados.
- Sugestões são valores derivados e não são persistidas como fatos financeiros no MVP.
- Uma sugestão nunca deve ser tratada como pagamento realizado.
- O algoritmo padrão é guloso, determinístico e não promete ótimo absoluto.
- Empates usam ordem estável documentada.
- A entrada do simplificador não pode ser modificada.

### Despesas

- Campos financeiros de uma despesa criada não são sobrescritos.
- Correção financeira significa anular a original e criar substituta na mesma transação.
- Despesas anuladas continuam no histórico e são ignoradas pelo ledger.
- A despesa deve possuir ao menos uma share e produzir ao menos uma obrigação para não pagador.
- Qualquer membro ativo pode registrar uma despesa e indicar outro membro ativo como pagador.
- `created_by_user_id` e `paid_by_user_id` devem ser preservados e exibidos separadamente.

### Pagamentos

- No MVP, o pagamento nasce de uma sugestão atual.
- Pagamento parcial é permitido até o valor ainda sugerido.
- Origem reporta; destino confirma.
- Origem ou destino pode cancelar enquanto `reported`.
- `confirmed` e `cancelled` são terminais no MVP.
- Não implemente reversão de pagamento confirmado sem atualizar domínio, UX, produto e specs.

### Grupos, convites e memberships

- Um grupo nasce com owner ativo na mesma transação.
- Convites do MVP são internos e destinados a usuários já cadastrados.
- Convite pendente não concede acesso nem participa financeiramente.
- Membership é único por grupo e usuário.
- Reentrada reutiliza o mesmo membership inativo.
- Não inative membership com saldo oficial/projetado diferente de zero ou pagamento pendente.
- O último owner não pode sair sem transferir a propriedade.
- Só arquive grupo `empty` ou `settled`, sem report ou convite pendente.

### Confiança e explicabilidade

- O MVP pressupõe grupos com confiança pré-existente.
- Não introduza aprovação ou disputa de despesa implicitamente.
- O destinatário sugerido pode diferir de quem pagou a despesa lembrada pelo usuário.
- A UI deve chamar isso de plano líquido ou sugestão, nunca de dívida bilateral presumida.
- Quando relevante, explique que a sugestão compensa o saldo do grupo e reduz transferências.

---

## 5. Transações, versão e idempotência

- Comandos financeiros devem ser atômicos.
- Serialize mudanças financeiras por grupo com lock de linha ou mecanismo equivalente.
- Incremente `financial_state_version` para toda mudança financeiramente material.
- `PaymentReporter` e correções financeiras devem validar `expected_financial_state_version` dentro da transação.
- Criação append-only de despesa é serializada e revalidada, mas não falha apenas porque outra criação ocorreu em paralelo.
- Operações sensíveis usam idempotency key e fingerprint canônico do payload.
- Mesma chave e mesmo payload retornam o resultado anterior.
- Mesma chave e payload diferente retornam conflito.
- Broadcasts e outros efeitos externos devem ocorrer depois do commit.

---

## 6. Autorização e privacidade

- Autorização existe no backend, não apenas na visibilidade dos botões.
- Todo acesso financeiro valida membership ativo no grupo correto.
- IDs conhecidos não concedem acesso.
- Action Cable valida membership antes de assinar streams.
- Owner não confirma pagamentos por terceiros no MVP.
- Não exponha descrições financeiras, tokens ou payloads desnecessários em logs.
- O destaque ao pagador indicado é contextual no app; não transforme isso em e-mail, push ou central de notificações sem mudança explícita de escopo.

---

## 7. Fluxo obrigatório de desenvolvimento

### 7.1 Contrato da tarefa

Antes da primeira alteração de comportamento, registre de forma concisa no plano de trabalho ou no relato da tarefa:

- fase atual e gate relacionado;
- fontes normativas consultadas;
- comportamento observável esperado;
- invariantes que devem permanecer verdadeiras;
- entradas válidas, inválidas, fronteiras e falhas esperadas;
- itens explicitamente fora do escopo;
- contratos afetados — domínio, banco, serviço, HTTP, autorização, UI, real-time ou deploy;
- classificação do impacto documental.

Classifique também cada comportamento previsto:

- **comportamento principal:** resultado solicitado e necessário para concluir a tarefa;
- **fallback autorizado:** comportamento secundário previsto pelo contrato para uma condição específica de degradação;
- **recuperação de erro:** resposta para uma falha; não é sucesso nem fallback por si só;
- **implementação parcial:** parte funcional do comportamento principal, ainda insuficiente para concluir a tarefa;
- **fora do escopo:** comportamento conscientemente não implementado nesta tarefa.

Todo fallback autorizado deve declarar a condição que o ativa, a razão de existir, o comportamento principal que continua obrigatório, como o sistema distingue degradação de sucesso, os sinais operacionais que permitem detectá-lo (métrica, log ou mensagem) e as specs separadas do caminho principal e do fallback. Sem essa autorização, a operação deve falhar explicitamente em vez de simular sucesso degradado.

Esse registro orienta o trabalho; ele não cria uma nova fonte normativa. Se o resultado esperado não puder ser extraído da documentação, não o deduza da implementação existente nem de convenções de outros produtos.

### 7.2 SDD — especificação antes da implementação

Mantenha separadas as três camadas:

1. **documentação normativa** define o contrato e o motivo;
2. **spec executável** demonstra o comportamento observável;
3. **implementação** é a menor solução que satisfaz ambos.

A implementação existente não prevalece sobre uma regra normativa apenas por já estar em produção ou passar na suíte. Uma spec também não cria silenciosamente regra de produto: quando ela expõe lacuna ou conflito documental, resolva a fonte normativa antes de consolidar o comportamento.

A especificação deve separar `caminho principal`, `caminho de erro` e cada `fallback autorizado`. Ela descreve o efeito observável principal, condições de sucesso, efeitos colaterais obrigatórios, falhas que permanecem visíveis, condições exatas de ativação de fallback, como usuário ou operador detecta a degradação e o que não conta como entrega concluída. Fallback não pode ser inferido durante a implementação porque o caminho principal é difícil. Se surgir uma necessidade legítima, interrompa o trabalho, registre a causa, proponha e sincronize a mudança de contrato na fonte normativa; somente então escreva as specs e implemente-o.

O comportamento principal solicitado faz parte do contrato da tarefa. Entregar somente um fallback não implementa o comportamento principal, não satisfaz a tarefa nem o gate e não pode ser relatado como concluído. Por exemplo, HTTP pode reconciliar o estado quando um stream falha, mas não substitui uma tarefa que solicita Action Cable; devolver a imagem original após `LoadError` não prova processamento com `ruby-vips`.

Construa em pequenas fatias verticais. Cada fatia deve entregar um contrato verificável de ponta a ponta no nível exigido pela fase, sem antecipar funcionalidades posteriores. Para o `DebtSimplifier`, por exemplo, implemente um contrato por vez — validação da soma, caso simples, múltiplos saldos, determinismo e propriedades — em vez de escrever todo o algoritmo antes das specs.

### 7.3 TDD verificável — Red, Green, Refactor

Para cada mudança de comportamento:

1. **Red:** escreva a menor spec que expressa o contrato, execute-a e confirme que falha pelo motivo esperado, não por boot, configuração ou fixture inválida.
2. **Green:** implemente apenas o necessário para essa spec passar e execute novamente a spec focada.
3. **Refactor:** melhore a estrutura sem alterar o contrato e rode a spec focada e o conjunto relacionado.

Regras contra falso verde:

- correções de bug começam com uma reprodução automatizada que falha;
- mudança de comportamento sem evidência de `Red` só é aceitável para scaffolding mecânico isolado, documentação pura ou refatoração comprovadamente sem mudança de comportamento;
- uma spec já existente e falhando pode fornecer o `Red`, desde que a falha esperada seja confirmada;
- não enfraqueça, remova ou torne genérica uma expectativa apenas para obter `Green`;
- não mocke o comportamento que está sendo testado nem substitua o objeto principal por uma simulação;
- não considere erro inesperado como `Red` válido;
- uma execução com zero exemplos não satisfaz gate que exige comportamento coberto;
- preserve no relato final os comandos e um resumo objetivo das evidências de `Red` e `Green`.

Regras adicionais para evitar fallback silencioso:

- **Red:** a spec inicial deve falhar porque o comportamento principal ainda não existe, não por configuração quebrada, dependência ausente sem relação com o contrato, fixture inválida, método incidental inexistente ou expectativa voltada ao fallback;
- **Green:** prove diretamente o efeito principal solicitado — por exemplo, o broadcast após commit, transformação observável de imagem, estado persistido, autorização e negação no backend, invariantes do algoritmo ou uma integração exercitada no nível real exigido;
- uma spec de fallback não substitui a spec do caminho principal, nem `200`, página renderizada, objeto não nulo ou ausência de exceção são prova suficiente de um efeito específico;
- não introduza fallback sem autorização explícita; não use `rescue StandardError`, `LoadError`, timeout, erro de configuração, integração ou persistência para convertê-los em sucesso;
- não esconda a falha com valor padrão, objeto nulo, resposta vazia, mock, stub, `no-op`, retorno estático ou feature flag desativada fora do escopo explícito da spec;
- não enfraqueça a expectativa para aceitar o fallback, nem remova uma asserção específica em favor de “não lança erro”;
- **Refactor:** não pode ampliar `rescue`, tornar dependência obrigatória opcional, trocar implementação real por `no-op`, reduzir precisão de expectativa, mover o principal para código não exercitado ou fazer o fallback virar padrão.

Depois do refactor, execute e relate separadamente as specs do caminho principal, dos erros e dos fallbacks autorizados, além do conjunto relacionado e da suíte completa.

Tarefas exclusivamente de verificação, testes de propriedade, isolamento arquitetural ou hardening não devem fabricar um `Red` quando o comportamento atual já satisfaz o contrato. Nesses casos:

- registre um `Red` real somente se a nova verificação encontrar um defeito real;
- caso contrário, demonstre a eficácia da spec com um controle negativo mínimo e deliberadamente defeituoso;
- mantenha mutantes, fixtures de violação e funções incorretas somente em `spec/` ou crie-os temporariamente na própria spec;
- não replique o algoritmo completo em uma segunda implementação de teste;
- nunca inclua controles negativos ou mutantes no código de produção.

### 7.4 Sequência de execução

Para cada tarefa:

1. Localize a fase do roadmap e seu gate.
2. Extraia regras e exemplos normativos e registre o contrato da tarefa.
3. Classifique o impacto documental.
4. Confirme `Ready`, dependências e contrato no GitHub Project; mova a tarefa para `In progress` ao iniciar a execução.
5. Execute o ciclo `Red -> Green -> Refactor` por pequena fatia.
6. Rode a spec focada.
7. Rode o conjunto relacionado.
8. Rode a suíte completa e as verificações aplicáveis da fase.
9. Rode lint, checagens de segurança e `bin/ci`, quando disponíveis e viáveis.
10. Valide build, configuração e execução Docker quando a infraestrutura for afetada.
11. Revise constraints, autorização, transações, concorrência, idempotência, acessibilidade e mensagens de erro conforme o contrato afetado.
12. Atualize todas as fontes documentais impactadas.
13. Atualize a subissue, a issue-pai e os campos do GitHub Project conforme a seção 7.5.
14. Relate contrato, evidências, arquivos alterados, testes e riscos restantes.

Não faça uma grande implementação antes das specs correspondentes, exceto scaffolding mecânico claramente isolado.

### 7.5 GitHub Project e Kanban

O [GitHub Project — Quitando](https://github.com/users/Luf3r/projects/2) é o quadro operacional obrigatório para execução do roadmap. Ele organiza o trabalho, mas não cria regras de domínio, produto, arquitetura ou gate e nunca prevalece sobre as fontes normativas da seção 2.

Estrutura vigente:

- issues de fase permanecem como épicos;
- somente a fase atual deve ser decomposta em pequenas subissues executáveis;
- cada subissue deve ter contrato principal, dependências explícitas, critérios verificáveis e definição objetiva de pronto;
- fases futuras permanecem no `Backlog` até a preparação da fase correspondente;
- o campo `Dependency` e as relações nativas de bloqueio devem permanecer coerentes entre si.

Use os status assim:

- `Backlog`: trabalho futuro ainda não preparado;
- `Ready`: fontes identificadas, contrato claro, dependências concluídas, tamanho adequado e evidência planejada;
- `In progress`: tarefa em execução; mantenha no máximo uma ou duas tarefas simultâneas;
- `Review`: implementação concluída, mas diff, specs, caminho principal, `bin/ci` ou documentação ainda aguardam confirmação;
- `Blocked`: falta decisão normativa, dependência, integração real ou evidência verificável válida;
- `Done`: contrato principal demonstrado, verificações concluídas, documentação reconciliada e issue-pai atualizada.

Ao iniciar uma tarefa:

- confirme `Phase`, `Priority`, `Size`, `Type`, `Dependency`, milestone, labels e issue-pai;
- mova apenas a subissue escolhida de `Ready` para `In progress`;
- mova a próxima tarefa para `Ready` somente depois que todas as dependências dela estiverem concluídas;
- não mova o épico para `Done` antes de demonstrar o gate completo da fase.

Ao concluir, bloquear ou alterar o escopo:

- atualize o status e os campos da subissue;
- registre na issue as evidências Red/Green ou o controle negativo aplicável, comandos executados, resultado e riscos;
- atualize checklist e progresso da issue-pai;
- reconcilie fase, capacidade e pendências em `PROJECT.md` e no README quando o estado público mudar;
- mantenha o Project consistente com o repositório real, sem promover implementação parcial ou fallback a entrega concluída.

Se o GitHub Project estiver inacessível ou a credencial não permitir a atualização, não simule sucesso: relate a divergência e o item que permanece pendente de sincronização.

---

## 8. Estratégia de testes

Priorize:

1. specs de objetos Ruby puros;
2. service specs;
3. constraints e model specs;
4. request e policy specs;
5. system specs para jornadas críticas;
6. testes de real-time e apresentação somente depois do fluxo HTTP.

Contratos especialmente importantes:

- conservação e sinais do ledger;
- soma das shares;
- valores zero, negativos, limites máximos e arredondamento residual;
- imutabilidade da entrada do algoritmo;
- determinismo;
- estabilidade sob permutações quando a ordem não faz parte do contrato;
- regra de desempate quando a ordem faz parte do contrato;
- `m - 1` transferências no máximo;
- projeção sem duplicar reports;
- idempotência com payload igual e diferente;
- reports concorrentes;
- confirmação única;
- atomicidade e rollback integral em falhas parciais;
- correção concorrente com report;
- broadcasts depois do commit;
- acesso entre grupos;
- reload HTTP equivalente ao estado atualizado por stream;
- explicação de destinatário contraintuitivo;
- distinção visual entre creator e pagador.

Para regras financeiras, combine exemplos legíveis, casos de fronteira e testes de propriedades. Verifique conservação, soma zero, sinais, limites, determinismo, imutabilidade, arredondamento, atomicidade, concorrência e idempotência sempre que forem aplicáveis.

Não persiga cobertura percentual isolada. Cubra invariantes, transições, falhas e fronteiras.

---

## 9. HTTP, Hotwire e interface

- Faça o fluxo funcionar por HTTP antes de adicionar real-time.
- Turbo Streams e Action Cable são melhoria progressiva, não fonte de verdade.
- Falha de broadcast não pode invalidar uma transação já persistida.
- A lista textual é o meio operacional principal.
- O grafo é complementar e precisa de tabela equivalente.
- Não dependa apenas de cor, animação ou toast.
- Respeite `prefers-reduced-motion` e gerenciamento de foco.
- Diferencie sempre:
  - saldo oficial;
  - saldo projetado;
  - pagamento pendente;
  - sugestão;
  - pagamento confirmado.

---

## 10. Ordem de implementação

Siga as fases do roadmap técnico. Não antecipe grafo, animações ou integrações antes de estabilizar ledger e comandos.

Resumo:

```text
Fase 0  fundação e CI
Fase 1  DebtSimplifier puro
Fase 2  schema e constraints
Fase 3  criação de despesas e arredondamento
Fase 4  saldo oficial
Fase 5  primeiro plano
Fase 6  saldo projetado
Fase 7  workflow de pagamentos
Fase 8  situação derivada do grupo
Fase 9  correção imutável de despesas
Fase 10 grupos, convites e memberships
Fase 11 requests, policies e HTML
Fase 12 Turbo Streams e Action Cable
Fase 13 visualização e acessibilidade
Fase 14 hardening, observabilidade e deploy
```

Uma fase só está concluída quando seu gate estiver atendido.

---

## 11. Comandos do projeto

Até o bootstrap do repositório, estes são os comandos canônicos planejados. Ajuste esta seção quando os scripts reais existirem.

```bash
bin/setup
bin/rails db:prepare
bundle exec rspec
bundle exec rubocop
```

Crie preferencialmente um comando único de CI:

```bash
bin/ci
```

`bin/ci` deve executar as verificações exigidas pelo projeto, incluindo suíte, lint e checagens de segurança adotadas no bootstrap.

Ao concluir uma tarefa, execute pelo menos:

- a spec focada alterada;
- o conjunto relacionado;
- `bin/ci`, quando disponível e viável.

Nunca afirme que testes passaram sem executá-los.

---

## 12. Mudanças de escopo ou domínio

### 12.1 Matriz de impacto documental

Classifique cada tarefa antes de implementar:

- **nenhum:** não altera contrato, decisão, fase ou capacidade descrita; registre a justificativa no relato final;
- **clarificação:** melhora a explicação sem mudar comportamento; sincronize todos os documentos que poderiam continuar ambíguos;
- **comportamento:** muda entrada, saída, validação, falha, autorização ou UI observável; atualize a fonte normativa, as specs e os exemplos afetados;
- **arquitetura:** muda uma decisão técnica aceita; crie novo ADR que substitua o anterior quando necessário e sincronize domínio, decisões consolidadas e índice;
- **escopo, fase ou gate:** muda o que será entregue ou a ordem de construção; atualize produto, roadmap e `PROJECT.md` de forma coerente.

Regras de manutenção:

- ADRs são históricos e append-only; nunca reescreva uma decisão aceita como se ela nunca tivesse existido;
- `PROJECT.md` só avança a fase ou marca um gate como concluído depois que todos os critérios forem demonstrados;
- o README descreve capacidades realmente disponíveis e não apresenta objetivo futuro como funcionalidade pronta;
- documentação normativa, decisões consolidadas, roadmap, UX e exemplos devem usar os mesmos termos para o mesmo conceito;
- se a classificação for **nenhum**, ainda assim informe no relato final que o impacto foi avaliado.

Ao iniciar e concluir uma tarefa, reconcilie a documentação de estado com o repositório real:

- mantenha a seção de milestone do `PROJECT.md` com fase atual, status, próxima fase, gate, entregas já verificadas e pendências reais;
- mantenha o GitHub Project com a mesma fase, tarefa ativa, dependências, bloqueios e conclusão demonstrada;
- atualize a fase para **em andamento** quando o trabalho nela começar, mas só a marque como concluída depois de demonstrar todo o gate;
- mantenha a seção de status do README coerente com as funcionalidades realmente utilizáveis e com as limitações atuais;
- substitua afirmações obsoletas como “a implementação ainda não existe” quando já houver fundação ou código, sem promover scaffolding a funcionalidade pronta;
- registre uma capacidade como implementada somente depois que código, specs e verificações aplicáveis existirem;
- quando a tarefa concluir ou alterar um item do roadmap, sincronize o estado compacto em `PROJECT.md` e qualquer relatório ou documento que ainda descreva a situação anterior;
- não transforme o roadmap normativo em changelog: preserve seus contratos e gates e registre o progresso nos campos de estado destinados a isso.

### 12.2 Critérios de parada

Interrompa a implementação e registre o bloqueio quando:

- fontes normativas aplicáveis entram em conflito;
- uma regra financeira necessária não está definida;
- seria preciso inventar fórmula, sinal, arredondamento, transição ou permissão;
- a mudança contradiz ADR aceito sem uma nova decisão explícita;
- a tarefa exige antecipar fase, item pós-MVP ou decisão adiada sem alteração aprovada de escopo;
- o comportamento esperado não pode ser expresso de forma testável com as informações disponíveis.
- o caminho principal não funciona e a única forma de obter verde é um fallback não autorizado;
- uma dependência obrigatória está ausente ou incompatível, a integração real teria de ser substituída por simulação em produção, ou seria necessário transformar erro em sucesso;
- a spec teria de ser enfraquecida, o fallback se tornaria o único caminho funcional, ou o comportamento principal não pudesse ser provado.

Não use o código atual para resolver silenciosamente esses casos. Continue apenas após a decisão ser documentada na fonte adequada.

### 12.3 Alterações que exigem sincronização normativa

Pare e atualize a documentação antes ou junto do código quando a mudança:

- adiciona novo estado;
- altera fórmula ou sinal;
- persiste plano de quitação;
- permite pagamento fora do plano;
- permite reverter `confirmed`;
- introduz aprovação ou disputa;
- introduz participante sem conta;
- altera a fronteira de confiança;
- adiciona multi-moeda;
- permite arquivar grupo aberto;
- transforma destaque contextual em sistema de notificações;
- muda a ordem de implementação ou o gate de uma fase.

Não implemente decisões adiadas “por conveniência”.

---

## 13. Definição de pronto para uma tarefa

Uma tarefa só está pronta quando:

- o contrato da tarefa foi registrado e atendido;
- mudanças de comportamento possuem evidência de `Red`, `Green` e refatoração quando aplicável;
- comportamento e falhas estão cobertos por specs adequadas;
- nenhuma execução com zero exemplos foi usada para satisfazer um gate comportamental;
- constraints de banco foram consideradas;
- autorização foi aplicada no backend;
- transação, versão e idempotência foram avaliadas quando relevantes;
- não há uso de `float` em dinheiro;
- o fluxo HTTP continua correto;
- acessibilidade foi considerada quando há UI;
- o impacto documental foi classificado;
- documentação afetada foi atualizada;
- fase atual, capacidades implementadas e pendências documentadas correspondem ao estado real do repositório;
- subissue, issue-pai e campos do GitHub Project correspondem ao trabalho realmente demonstrado;
- spec focada, conjunto relacionado e `bin/ci` foram executados quando disponíveis e viáveis;
- testes não executados e respectivas razões são informados;
- nenhum item fora do MVP foi introduzido implicitamente.

Para todo contrato com comportamento principal, inclua e preencha esta matriz de evidência; a tarefa não está pronta se algum campo aplicável não puder ser preenchido:

```text
Contrato solicitado:
Comportamento principal:
Spec que prova o caminho principal:
Fallbacks autorizados:
Specs dos fallbacks:
Erros que permanecem visíveis:
Evidência de que o fallback não é o caminho padrão:
```

Além disso, o comportamento principal deve estar implementado e provado por uma spec que falhou antes; cada fallback deve ser autorizado, ter condição limitada e spec própria; erros inesperados devem permanecer visíveis; a suíte verde não pode resultar de expectativas enfraquecidas, mocks, `no-ops`, valores padrão ou execuções com zero exemplos. Não marque tarefa, fase ou gate como concluído enquanto só o fallback funcionar.

---

## 14. Relato final do agente

Ao terminar, informe de forma objetiva:

- o que mudou;
- qual contrato da tarefa foi atendido e a qual fase/gate ele pertence;
- quais arquivos foram alterados;
- qual foi a evidência de `Red` e de `Green` para mudanças de comportamento;
- quais specs e comandos foram executados, separando execução focada, relacionada, suíte e `bin/ci`;
- resultado dos testes;
- quais issues e campos do GitHub Project foram atualizados e para quais status;
- qual foi a classificação do impacto documental e quais fontes foram sincronizadas;
- decisões ou suposições adotadas;
- riscos, limitações ou trabalho restante.

Separe o relato em **Implementado** (somente o que foi demonstrado), **Fallbacks** (condição, limitação e specs), **Não implementado**, **Bloqueios** e **Evidências**. Não use frases como “implementei com fallback”, “há suporte através de uma alternativa”, “o fluxo continua funcionando”, “a suíte está verde” ou “solução resiliente” sem dizer se o comportamento principal funciona, quando o fallback ativa, suas limitações e qual spec prova cada caminho. Quando apenas o fallback funcionar, declare literalmente que o comportamento principal solicitado não foi implementado e que a tarefa permanece incompleta.

Não esconda falhas, testes não executados ou incertezas.
