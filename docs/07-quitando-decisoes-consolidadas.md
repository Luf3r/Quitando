# Quitando — Decisões Consolidadas

Este arquivo resume decisões que precisam permanecer consistentes entre produto, domínio, interface e implementação. Para a ordem de leitura, consulte [`00-index.md`](./00-index.md).

## Navegação rápida

- [1. Decisões consolidadas](#1-decisões-consolidadas)
- [2. Decisões conscientemente adiadas](#2-decisões-conscientemente-adiadas)
- [3. Hipóteses que ainda exigem validação](#3-hipóteses-que-ainda-exigem-validação)
- [4. Regra para futuras alterações](#4-regra-para-futuras-alterações)
- [5. Arquivos de orientação para agentes de código](#5-arquivos-de-orientação-para-agentes-de-código)
- [6. Relação com os ADRs](#6-relação-com-os-adrs)

---


## 1. Decisões consolidadas

### Produto

- O produto resolve o **encerramento de despesas compartilhadas**, não apenas o cadastro de gastos.
- O modo padrão reduz transferências, mas não promete o mínimo matemático absoluto.
- O plano textual é a ferramenta operacional principal; o grafo é explicativo e demonstrativo.
- O MVP trabalha com usuários autenticados, uma moeda por grupo, convites internos para contas existentes (`pending/accepted/declined/revoked/expired`) e pagamentos manuais declarados.
- O produto pressupõe grupos de confiança pré-existente; ele não é desenhado para desconhecidos ou relações adversariais no MVP.
- A obrigação histórica pode apontar para uma pessoa e o plano líquido para outra; a interface deve explicar essa diferença sem chamar a sugestão de dívida bilateral.
- Arquivamento só ocorre quando o grupo está vazio ou quitado, sem pendências ou convites abertos; o owner pode restaurá-lo sem alterar o ledger.
- O roadmap funcional define o que entra no release; a ordem técnica prioriza algoritmo, ledger e comandos financeiros antes de HTTP reativo e visualização.
- Após o MVP, a interface deve evoluir para suportar múltiplos idiomas; locale altera apresentação e linguagem, não as regras do ledger nem a moeda definida para o grupo.

### Domínio

- Despesas, shares e pagamentos confirmados determinam o **saldo oficial**.
- Pagamentos `reported` não alteram o saldo oficial, mas são considerados no **saldo projetado** para que o sistema não sugira novamente uma transferência já declarada.
- O plano acionável é calculado a partir dos saldos projetados.
- Sugestões não são persistidas como fatos financeiros.
- Reports existentes não são cancelados automaticamente quando novas despesas mudam o plano; eles permanecem declarações separadas na projeção.
- Um pagamento no MVP só pode ser reportado a partir de uma sugestão atual e por valor positivo não superior ao sugerido.
- Campos financeiros de uma despesa são corrigidos por anulação e substituição, não por sobrescrita.
- Qualquer membro ativo pode registrar despesa indicando outro pagador ativo; creator e pagador são auditados separadamente e o pagador recebe destaque contextual no aplicativo.
- Membership inativo é reativado no mesmo registro, preservando histórico.
- Toda alteração que possa mudar saldo, projeção ou plano incrementa `financial_state_version`.

### Estados

- Pagamento: `reported -> confirmed` ou `reported -> cancelled`.
- Somente o recebedor confirma; pagador e recebedor podem cancelar uma declaração pendente, com ator e motivo registrados.
- Situação derivada do grupo: `empty`, `open`, `awaiting_confirmation` ou `settled`.
- Um grupo só está `settled` quando possui atividade financeira, todos os saldos oficiais são zero e não existe pagamento `reported`.

### Consistência

- Comandos financeiros são revalidados dentro de transação e serializados por grupo.
- Reports e correções financeiras enviam a versão financeira esperada; criação append-only de despesa é serializada, mas não falha apenas porque outra criação ocorreu em paralelo.
- Broadcasts ocorrem depois do commit e nunca substituem a leitura por HTTP.
- Edições históricas não apagam fatos silenciosamente; correções preservam ator, motivo e relação com o registro substituído.

---

## 2. Decisões conscientemente adiadas

- participantes sem conta e `Participant` separado de `User`;
- fechamento formal por períodos ou ciclos de quitação;
- solver exato em produção;
- multi-moeda;
- suporte a múltiplos idiomas e localização da interface;
- disputas;
- pagamentos bancários reais;
- API e webhooks externos;
- cache ou persistência de planos;
- reversão vinculada de pagamento confirmado, reversão bancária, chargeback e conciliação automática;
- convites por link ou participação sem conta;
- contestação formal de despesa;
- modo alternativo de acerto direto que preserve relações históricas em vez de priorizar redução de transferências.

Essas decisões não impedem o MVP, mas não devem ser implementadas implicitamente sem atualizar a documentação.

---

## 3. Hipóteses que ainda exigem validação

- a confirmação dupla gera mais confiança do que fricção;
- usuários percebem valor suficiente na redução de transferências;
- a lista textual resolve a tarefa melhor que o grafo;
- pagamentos parciais são frequentes o bastante para permanecer no MVP;
- grupos contínuos, como repúblicas, conseguem operar sem um conceito formal de período no primeiro release;
- convite interno restrito a usuários cadastrados não cria fricção excessiva;
- a ausência de reversão de pagamento confirmado é aceitável no MVP;
- usuários aceitam destinatários sugeridos diferentes da pessoa a quem sentem dever diretamente;
- grupos de confiança aceitam registros em nome de outro pagador com autoria e aviso contextual transparentes.

---

## 4. Regra para futuras alterações

Uma mudança deve atualizar todos os documentos afetados. Exemplos:

- adicionar `rejected` ao pagamento exige revisão de domínio, produto e UX;
- permitir pagamentos fora do plano exige novos invariantes e regras de concorrência;
- transformar despesas registradas por terceiros em fluxo de aprovação exige novos estados, efeitos no ledger e comportamento de expiração/rejeição;
- introduzir convidados exige trocar referências diretas a `User` por um conceito de participante;
- permitir arquivar grupos abertos exige definir se comandos financeiros continuam disponíveis;
- reverter pagamentos confirmados exige evento compensatório vinculado e novas permissões;
- persistir planos exige definir validade, versão e comportamento quando o ledger muda.

---

## 5. Arquivos de orientação para agentes de código

Estes arquivos são atalhos operacionais e não substituem as fontes normativas:

1. [`PROJECT.md`](../PROJECT.md) — contexto compacto, escopo, fluxo e arquitetura em alto nível;
2. [`AGENTS.md`](../AGENTS.md) — regras obrigatórias de desenvolvimento, TDD, verificação e definição de pronto;
3. [`CLAUDE.md`](../CLAUDE.md) — adaptador curto para ferramentas que consultem esse nome;
4. [`CODEX.md`](../CODEX.md) — adaptador curto para o fluxo de trabalho com Codex.

`CLAUDE.md` e `CODEX.md` não devem acumular regras próprias. Toda regra compartilhada deve viver em `AGENTS.md`; decisões de produto e domínio continuam nos documentos normativos.

---

## 6. Relação com os ADRs

Este documento resume as decisões vigentes. Os arquivos em [`adr/`](./adr/) registram o contexto, a decisão, as consequências e as alternativas consideradas.

- uma decisão aceita não deve ser reescrita silenciosamente;
- mudança material cria um novo ADR que **supersede** o anterior;
- correções editoriais podem ser feitas sem alterar o sentido;
- código e documentação normativa devem refletir o ADR vigente.
