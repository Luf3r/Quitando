# Task 2 — relatório: criar e renomear grupos

## Contrato da tarefa

- **Fase/gate:** Fase 10, entrega 10.2; contribui para o gate de formar e administrar o grupo sem duplicar histórico ou fragilizar o domínio financeiro.
- **Fontes consultadas:** `AGENTS.md` §§4–7, 12–13; `docs/05-quitando-roadmap-implementacao.md` §13; `docs/03-quitando-domain-architecture.md` §§5.2, 6.1–6.2, 8.6 e 10.1; ADR-0010 e ADR-0015; `.superpowers/fase-10-groups-plan.md`; `task-2-brief.md`.
- **Comportamento principal:** `GroupCreator` valida o UUID v7 canônico do owner antes de consultar, normaliza um nome não vazio e cria, em uma transação, grupo BRL e membership `owner/active` na posição zero. `GroupNameUpdater` valida seus dois UUIDs antes de consultar, exige membership owner ativa, recusa grupo arquivado e persiste o nome normalizado.
- **Invariantes:** grupo novo nunca persiste sem owner inicial; `currency_code` é BRL; nomes persistidos não são vazios; `financial_state_version` permanece zero/invariada; autorização é aplicada no serviço; falha da criação de membership reverte o grupo.
- **Entradas e falhas:** UUIDs não canônicos, nomes não-string/em branco e owner inexistente retornam erro de entrada/ausência tipado; grupo ausente, ator não-owner/inativo e grupo arquivado retornam erros de domínio tipados. A validação de ID precede qualquer consulta sensível.
- **Fora do escopo:** convite, HTTP/controllers/policies/UI, realtime/e-mail, arquivar/restaurar e gestão de memberships.
- **Contratos afetados:** domínio, serviço, banco/transaction e autorização de domínio. Não afeta HTTP, UI, real-time ou deploy.
- **Impacto documental:** nenhum — implementa contrato já normatizado, sem alterar comportamento normativo, fase ou decisão.
- **Classificação:** somente comportamento principal e caminhos de erro; não há fallback autorizado.

## Evidências TDD

- **Correção do relato histórico:** as execuções iniciais que falharam no carregamento com `NameError` e executaram zero exemplos não constituem Red válido conforme `AGENTS.md` §7.3. Elas demonstraram somente ausência de constantes e não são usadas como evidência comportamental desta tarefa.
- **Controle negativo de hardening (separado do Green):** como a implementação já existia e satisfazia o contrato, foi criado temporariamente `spec/services/task_2_validation_negative_control_spec.rb`. O mutante test-only antepunha `User.find_by` ao `GroupCreator#call` e `Group.find_by` ao `GroupNameUpdater#call`, simulando consulta sensível antes da validação. `docker compose run --rm web bundle exec rspec spec/services/task_2_validation_negative_control_spec.rb --example 'antes de consultar'` concluiu com status 1 e `12 examples, 12 failures`; todos falharam com `RSpec::Mocks::MockExpectationError` na consulta proibida. O arquivo temporário foi removido e nunca integrou produção.
- **Green/refactor fortalecidos:** as specs agora observam diretamente a primeira consulta sensível (`User.find_by` no creator e `Group.find_by` no updater), em vez de inferirem a ordem pela ausência de transação. Há exemplos independentes para owner do creator e para `group_id` e `actor_user_id` do updater, cada qual cobrindo UUID v7 válido em maiúsculas, variante RFC inválida, string malformada e valor não-string. `docker compose run --rm web bundle exec rspec spec/services/group_creator_spec.rb spec/services/group_name_updater_spec.rb` concluiu com `22 examples, 0 failures`.
- **Lint focado:** `docker compose run --rm web bundle exec rubocop app/services/group_command.rb app/services/group_creator.rb app/services/group_name_updater.rb spec/services/group_creator_spec.rb spec/services/group_name_updater_spec.rb` concluiu sem ofensas.
- **Conjunto relacionado histórico:** `docker compose run --rm web bundle exec rspec spec/services` havia sido executado no container após a implementação original; não substitui as evidências focadas e frescas acima. A checagem de `bin/ci` fica para o controlador da fase.

## Arquivos alterados

- `app/services/group_command.rb`
- `app/services/group_creator.rb`
- `app/services/group_name_updater.rb`
- `spec/services/group_creator_spec.rb`
- `spec/services/group_name_updater_spec.rb`
- `.superpowers/sdd/fase-10-groups-plan/task-2-report.md`

## Riscos e pendências

- Nenhum fallback foi introduzido.
- O host não possui Ruby/Bundler configurados com as gems do lockfile; todas as evidências RSpec e RuboCop acima usam o Docker Compose do projeto.
- `db/structure.sql` já estava modificado no worktree e não pertence a esta tarefa nem será incluído no commit.
