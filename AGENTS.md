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

Antes de implementar:

- inspecione o código e as specs existentes;
- identifique a fase e o gate do roadmap;
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

Esse registro orienta o trabalho; ele não cria uma nova fonte normativa. Se o resultado esperado não puder ser extraído da documentação, não o deduza da implementação existente nem de convenções de outros produtos.

### 7.2 SDD — especificação antes da implementação

Mantenha separadas as três camadas:

1. **documentação normativa** define o contrato e o motivo;
2. **spec executável** demonstra o comportamento observável;
3. **implementação** é a menor solução que satisfaz ambos.

A implementação existente não prevalece sobre uma regra normativa apenas por já estar em produção ou passar na suíte. Uma spec também não cria silenciosamente regra de produto: quando ela expõe lacuna ou conflito documental, resolva a fonte normativa antes de consolidar o comportamento.

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

### 7.4 Sequência de execução

Para cada tarefa:

1. Localize a fase do roadmap e seu gate.
2. Extraia regras e exemplos normativos e registre o contrato da tarefa.
3. Classifique o impacto documental.
4. Execute o ciclo `Red -> Green -> Refactor` por pequena fatia.
5. Rode a spec focada.
6. Rode o conjunto relacionado.
7. Rode a suíte completa e as verificações aplicáveis da fase.
8. Rode lint, checagens de segurança e `bin/ci`, quando disponíveis e viáveis.
9. Valide build, configuração e execução Docker quando a infraestrutura for afetada.
10. Revise constraints, autorização, transações, concorrência, idempotência, acessibilidade e mensagens de erro conforme o contrato afetado.
11. Atualize todas as fontes documentais impactadas.
12. Relate contrato, evidências, arquivos alterados, testes e riscos restantes.

Não faça uma grande implementação antes das specs correspondentes, exceto scaffolding mecânico claramente isolado.

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
- spec focada, conjunto relacionado e `bin/ci` foram executados quando disponíveis e viáveis;
- testes não executados e respectivas razões são informados;
- nenhum item fora do MVP foi introduzido implicitamente.

---

## 14. Relato final do agente

Ao terminar, informe de forma objetiva:

- o que mudou;
- qual contrato da tarefa foi atendido e a qual fase/gate ele pertence;
- quais arquivos foram alterados;
- qual foi a evidência de `Red` e de `Green` para mudanças de comportamento;
- quais specs e comandos foram executados, separando execução focada, relacionada, suíte e `bin/ci`;
- resultado dos testes;
- qual foi a classificação do impacto documental e quais fontes foram sincronizadas;
- decisões ou suposições adotadas;
- riscos, limitações ou trabalho restante.

Não esconda falhas, testes não executados ou incertezas.
