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

- **Red (primeiro caminho principal):** `docker compose run --rm web bundle exec rspec spec/services/group_creator_spec.rb` falhou ao carregar a spec com `NameError: uninitialized constant GroupCreator` e nenhum exemplo executado; a constante e o comportamento ainda não existiam.
- **Green (primeiro caminho principal):** o mesmo comando concluiu com `1 example, 0 failures` depois da implementação mínima de `GroupCommand` e `GroupCreator`.
- **Red (contrato completo):** `docker compose run --rm web bundle exec rspec spec/services/group_creator_spec.rb spec/services/group_name_updater_spec.rb` falhou ao carregar com `NameError: uninitialized constant GroupCreator` e `NameError: uninitialized constant GroupNameUpdater`; ambos os comandos ainda estavam ausentes após recomeçar a implementação para cobrir todos os caminhos antes do código.
- **Green/refactor:** o mesmo comando concluiu com `12 examples, 0 failures` após introduzir os três serviços. A primeira execução do conjunto completo revelou que as fixtures de validação de nome usavam UUID v4; elas foram corrigidas para UUID v7 canônico, preservando a regra de validar identificador primeiro. A nova execução concluiu com `12 examples, 0 failures`.
- **Lint:** `docker compose run --rm web bundle exec rubocop app/services/group_command.rb app/services/group_creator.rb app/services/group_name_updater.rb spec/services/group_creator_spec.rb spec/services/group_name_updater_spec.rb` concluiu com `5 files inspected, no offenses detected`.
- **Conjunto relacionado:** `docker compose run --rm web bundle exec rspec spec/services` foi executado no container após a checagem focada; não foi usada como substituta da evidência focada. A checagem de `bin/ci` fica para o controlador da fase.

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
