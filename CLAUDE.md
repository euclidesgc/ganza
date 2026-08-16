# ganza

**Ganzá** é um assistente pessoal de registro: você manda uma mensagem em linguagem natural e o sistema estrutura — transação, compromisso, rotina, tarefa, nota. O produto, os requisitos e as fases estão em [`docs/plano.md`](docs/plano.md); o estado de execução, em [`docs/roadmap.md`](docs/roadmap.md). **Na dúvida sobre "o quê" e "por quê", o plano manda. Sobre "como", este arquivo manda.**

O nome no repositório, no `applicationId`, nos pacotes e na URL é **`ganza`, sem acento**. "Ganzá" só aparece na tela.

## Layout do repositório

- `app/` — Flutter, **um único código para Android e Web**. Não são dois projetos: é o mesmo `lib/` com dois alvos de build.
- `supabase/functions/` — **Edge Functions em Deno**. Toda a lógica de servidor: `ingest`, `sync-finance`, `finance-math`, `notify`, `calendar`. **Dona exclusiva de toda chave de terceiro** (Gemini, Pluggy, Google, FCM). `main/index.ts` roteia `/functions/v1/<nome>`; publicar é `scripts/deploy-functions.sh`.
- `supabase/migrations/` — SQL versionado. Schema, RLS, `pg_cron`.
- `infra/coolify/` — compose e variáveis de ambiente da stack self-hosted.
- `docs/NN-<nome>/` — docs vivas de cada feature (`specs.md`, `prd.md`, `plan.md`, `variance_report.md`, `test_plan.md`, `final_report.md`, `evidencias/rodada_MM/`). **`NN`** é o número de sequência com dois dígitos na ordem de desenvolvimento (`01`, `02`, …). Pastas de referência (`deploy/`, `specs/`) **não** são numeradas.

**Um app, sem packages.** O produto é um app só — módulo mora em `app/lib/modules/<nome>_module/`, não em pacote separado. Extrair para `packages/` só quando um segundo consumidor existir de verdade; cerimônia de monorepo sem segundo consumidor é custo sem retorno.

## Arquitetura de servidor — quem faz o quê

O desenho é **Supabase enxuto + backend próprio**. A divisão é rígida:

| Camada | Responsabilidade | O que **nunca** faz |
|---|---|---|
| **Supabase** (Postgres, GoTrue, PostgREST, Storage, pg_cron) | Persistência, autenticação, RLS, arquivos, agendamento | Não guarda regra de negócio em plpgsql. |
| **Edge Functions** (Deno, no mesmo Supabase) | Toda lógica: interpretação de mensagem, chamadas de IA, Pluggy, Google Calendar, matemática financeira, push | Não guarda estado próprio. |
| **App Flutter** | UI, captura, confirmação, leitura de dados via `supabase_flutter` | **Não fala com nenhuma API externa.** Nem Gemini, nem Pluggy, nem Google. Só o Supabase. |

- **Leitura** de dados do usuário: app → `supabase_flutter` (PostgREST + RLS). Não passa pelo backend.
- **Escrita que exige lógica** (interpretar, categorizar, calcular, conciliar): app → Edge Function → Postgres.
- **Trabalho agendado**: `pg_cron` → `pg_net` chama a Edge Function por HTTP com segredo do Vault. Nunca lógica dentro de function SQL.

## Invariantes de produto (o QA e o CISO cobram, não são sugestão)

Regras do `docs/plano.md` que viram gate de código:

1. **Nada vira registro sem confirmação explícita.** Não existe caminho de gravação automática — nem para tipo de baixo risco, nem com confiança alta. Toda proposta nasce em `proposed_actions` com `status` e só migra para a tabela final com `confirmed`. Uma mensagem gera **lista** de propostas, nunca objeto único.
2. **Card de confirmação não é editável.** Confirmar ou cancelar. Corrigir é na tela do registro, fora do chat — a intenção `update` não existe.
3. **Cálculo financeiro é código determinístico, nunca IA.** Juros, amortização (Price/SAC), quitação antecipada e conciliação moram em `/finance-math`, testados. O modelo interpreta o pedido; quem calcula é a função.
4. **Nenhuma credencial no cliente.** APK se descompila: chave de IA, Pluggy, Google e FCM vivem no Vault/env do backend. `--dart-define` **não** é lugar de segredo (fica no binário).
5. **RLS em todas as tabelas desde a primeira migration**, política `user_id = auth.uid()`. Tabela nova sem RLS é migration rejeitada.
6. **Storage sempre por URL assinada**, nunca bucket público.
7. **O app não insiste.** Atrasada para de notificar em 3 dias e permanece na lista. Sem confete, sem streak, sem parabéns.
8. **Toda chamada de IA grava custo e latência em `ai_usage`**, e toda rota tem fallback. O app pede "execute a tarefa X", nunca "chame o provedor Y".

## Regras inegociáveis (Flutter/Dart)

- Clean Architecture por módulo: `app/lib/modules/<nome>_module/{domain,data,presentation}` + `<nome>_routes.dart` + `<nome>_injection.dart` + barrel público `<nome>_module.dart` que expõe **só** a rota e o registro de DI.
- **domain** = Dart puro; entidades imutáveis (`Equatable`, sem `fromMap`/`toMap`); contratos `abstract interface class` devolvendo `Future<Either<Failure, T>>` (fpdart); **um use case por operação** (método `call()`), mesmo passa-fica.
- **data** = models com (de)serialização validada por **zard** (`safeParse` → `Either`); impl do repositório atrás do contrato; **único lugar com try/catch** — traduz `PostgrestException`/`AuthException`/`StorageException`/`DioException` → `Failure` tipada de `core/error/`.
- **presentation** = `Cubit` (flutter_bloc) com estado `sealed class` + `switch` exaustivo (states via `part of`); página `StatelessWidget` com `static Widget pageBuilder` — **o único lugar que toca o get_it**. Guarda `isClosed` após `await` antes de `emit`.
- **Escopo mínimo de rebuild.** Nunca reconstrua uma tela inteira a cada tecla/tick: escope o rebuild ao menor pedaço que muda. Cubit escopado + `BlocSelector`/`buildWhen`, ou widget-folha pequeno para estado **efêmero** (hover, foco, drag). Estado nunca mora no topo de uma tela grande sob um `BlocBuilder` único. Isole o caro com `RepaintBoundary`.
- **presentation NUNCA importa data.** Nenhum módulo importa o interno de outro (só o barrel público). Lógica recebe dependências pelo construtor. **Única exceção, documentada:** o barrel do `auth_module` exporta também o contrato de sessão (`AuthenticatedUser`, `ObserveCurrentUser`, `SignOut`), porque autenticação é transversal — a guarda de rota da raiz e qualquer tela com "sair" dependem dela. Repositório, models, cubits e páginas do auth continuam internos.
- Navegação: go_router; rotas por módulo em classe `XRoutes` (`static GoRoute get route` + constantes); sempre variantes `*Named`; nada de `extra:` (some no refresh web).
- Erros imprevistos: `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` + `AppBlocObserver` no `bootstrap.dart`.
- Flavors: `main_dev.dart`/`main_prod.dart` → `bootstrap(AppConfig)`; config via `--dart-define-from-file=config/<env>.json`; **segredo nunca em dart-define**.
- **Zero build_runner** (nada de freezed, json_serializable, injectable, mockito, go_router_builder).
- Testes: `test/` espelha `lib/`; `mocktail` (`MockX extends Mock implements X`) + `bloc_test`; a bateria automatizada é escrita **por último**, após o E2E atestado.
- Acessibilidade: cor nunca é o único sinal de informação; controles com `Semantics`/tooltip; alvos de toque grandes (o app se usa com uma mão).
- Arquivos `snake_case`, classes `PascalCase`, **uma classe/widget por arquivo**; código em inglês, UI e docs em pt-BR. Única exceção: o estado `sealed` do cubit mora no mesmo arquivo do cubit via `part of`.
- **Zero comentário — o código se explica por nomes.** Vale para Dart, TypeScript e SQL. **Não escreva** comentário que diga o que a linha faz, que repita o nome do identificador logo abaixo, cabeçalho decorativo de seção, nem nota de autoria/histórico ("antes era X", "adicionado na F2") — para isso existe o git. Legibilidade se conquista **extraindo** variável/função/widget com nome descritivo. **Única exceção:** o **porquê** que o código não tem como mostrar — decisão de arquitetura, workaround de bug externo, restrição de plataforma ou invariante não óbvia; e aí o comentário explica a **razão**, nunca a mecânica. Ao editar arquivo já comentado, limpe o que não passa nesse teste.
- Cancela de máquina: **`flutter analyze` verde + testes passando é o mínimo, não o "pronto".** O pronto é o DoD da etapa — ver "DoD por etapa". Nunca opinião.

## Design system e organização de widgets (inegociável)

Os tokens saem da identidade do `docs/plano.md` §11 — paleta de couro/palha/ocre/latão, **Fraunces** nos títulos e **IBM Plex Sans** no corpo (algarismos tabulares são requisito, não gosto: coluna de valores não pode dançar entre linhas). Gates cobrados na `revisar-fase`, na `criar-modulo` e pelo guard-script do CI.

- **Gate 1 — Zero função/método que retorna `Widget`.** Cada pedaço de UI é um `Widget` próprio (`StatelessWidget`/`StatefulWidget`) recebendo dados **pelo construtor** — nunca `Widget _buildX(...)`. Preserva `const`, isolamento de rebuild e reuso. **Não são o anti-padrão** (permitidos): o `build()` override, o `static Widget pageBuilder`, e os callbacks de builder do framework (`itemBuilder`, `builder:`) — mas quando não-triviais devem delegar a um widget dedicado, não montar árvore inline extensa.
- **Gate 2 — Widget mora por proximidade.** Três tiers: **feature** (`.../presentation/<feature>/widgets/`) → **módulo** (`modules/<x>_module/presentation/widgets/`, usado por mais de uma feature do módulo) → **app-wide** em `app/lib/core/widgets/` (o "components": por categoria em subpastas, cada uma com barrel; barrel raiz `core/widgets/widgets.dart`). Widget usado por vários módulos sobe para `core/widgets/`. Ao promover, mova de tier e ajuste os barrels.
- **Gate 3 — Uma classe/widget por arquivo.** Widget novo = arquivo novo `snake_case`. O alvo real são arquivos gordos entupidos de widgets distintos. **Não são violação** (podem coabitar): o par `StatefulWidget`+`State`, o cubit e seus estados via `part of`, uma família `sealed` e enums agrupados num `*_enum.dart`.
- **Gate 4 — Tema-token, zero hardcode.** Cor, tipografia, espaçamento, raio, elevação e duração vivem **agrupados em `app/lib/core/theme/`** (tokens tipados: `AppColors`/`AppTypography`/`AppSpacing`/`AppRadii`/`AppDurations` + `ThemeExtension` quando não couber no `ThemeData`) e são consumidos via `Theme.of(context)`/token — **nunca** `Color(0x…)`, `EdgeInsets.all(16)`, `TextStyle(fontSize: …)` cru. Tokenizar tudo, com variante dark mesmo quando hoje não varia. Trocar ou criar tema = mexer **só** em `core/theme/`.

**Princípios de interface** (do plano §11.4, valem mais que a paleta): o app sustenta por baixo, não disputa atenção; a tela inicial mostra hoje e esta semana, relatório se vai buscar; toca-se com uma mão, chat sempre a um toque; material humilde — superfícies chapadas, sem vidro fosco nem sombra pesada.

## Regras das Edge Functions e do banco

- **`index.ts` é só a borda**: `Deno.serve(handler)` e nada mais. O comportamento mora num `handler.ts` exportado, para ser testado sem subir servidor.
- **Valide toda entrada na borda** (zod ou validação explícita) — nenhum `any` atravessa, e JSON externo nunca vira objeto de domínio sem schema.
- **Use o JWT do usuário, não a `service_role`, sempre que der.** Com o `Authorization` da requisição, a RLS se aplica sozinha. A `service_role` fura RLS por definição: reserve-a para trabalho agendado sem usuário, e escreva no código por que era necessária.
- **Publicar é `scripts/deploy-functions.sh`** — no self-hosted não existe `supabase functions deploy`. Função apagada do repositório some do servidor.
- **A camada de IA é abstraída** (`ai_providers`/`ai_routes`): o código chama `execute(taskType, input)`, o provedor/modelo vem da tabela. Trocar provedor de um `task_type` não recompila nada. Toda chamada grava em `ai_usage`.
- **Transcrição e extração são `task_type` separados** mesmo quando o mesmo modelo faria as duas numa chamada — quando errar, é preciso saber qual etapa falhou.
- **Migration é `.sql` versionado em `supabase/migrations/`**, nome `NNNN_<verbo>_<alvo>.sql`, e **aplica limpo num banco vazio** (o CI valida isso). Toda tabela nasce com RLS e política. Sem ORM que gere schema: o SQL é a fonte da verdade.
- **`pg_cron` só agenda e chama HTTP** (`pg_net` → endpoint do backend). Regra de negócio não mora em plpgsql.
- Segredo nunca no repo — só env no Coolify e Vault do Supabase.

## Método de trabalho (time de IA)

O usuário invoca **`/tech-manager <pedido>`** (skill em `.claude/skills/tech-manager/`, que roda na própria conversa e orquestra os agentes de `.claude/agents/`; não é sub-agente) — o fluxo completo mora lá. Regras que valem sempre: 1 fase = 1 PR; **só então** testes automatizados, depois do E2E atestado; desvio do plano só entra com aprovação do humano e registro em `variance_report.md`.

### O time e o que cada um alcança

Cada agente declara suas `tools` no frontmatter. **A restrição é a regra de fatia, escrita de forma que a máquina cobre** — um agente sem `Write` não conserta por engano, um sem `WebFetch` não sai falando com API de terceiro. Ao criar ou alterar um agente, ajuste as tools junto: fatia e ferramenta andam sempre no mesmo commit.

| Agente | Modelo | Fatia | Alcance notável |
|---|---|---|---|
| `product-manager` | opus | discovery, `specs.md`, `prd.md` | **sem `Bash` e sem grafo** — não roda comando nem varre código |
| `tech-lead` | opus | `plan.md`, fatiamento, depuração do E2E | **único com `Agent`** (delega varredura) + grafo completo |
| `qa` | opus | validação de fase, E2E, testes, docs | `Skill` (encadeia as próprias skills) + `run_tests` |
| `ciso` | sonnet | segurança e privacidade | **sem `Write`/`Edit`** — cancela não conserta o que revisa |
| `especialista-dominio` | sonnet | entidades, contratos, use cases | fatia fechada: sem `Agent`, sem web |
| `especialista-dados` | sonnet | models, repositórios, Supabase/Dio | **sem `WebFetch`** — quem fala com o mundo é o backend |
| `especialista-apresentacao` | sonnet | cubits, páginas, tema | **único com app rodando** (`hot_reload`, `get_widget_tree`) |
| `especialista-backend` | sonnet | Edge Functions, IA, integrações, migrations, RLS | **único com `WebFetch`/`WebSearch`**; `psql` só em banco descartável |
| `especialista-infra` | sonnet | `core/`, DI, router, notificações, build, Coolify | **maior raio de ação: `Bash` alcança a VPS de produção** — muda estado no servidor só com confirmação do humano |

### Skills e política de invocação

Toda skill declara `allowed-tools` e **todas são auto-invocáveis pelo modelo**, exceto uma:

| Skill | Auto? | Para quê |
|---|---|---|
| `tech-manager` | **não** (`disable-model-invocation`) | é o ponto de entrada do humano e dispara o time inteiro; auto-invocar tomaria o controle da conversa e custaria caro. Vira automática apagando uma linha do frontmatter. |
| `criar-modulo` · `criar-migration` | sim | gabarito de módulo Flutter e de migration com RLS |
| `fechar-etapa` | sim | **verifica o DoD rodando, antes de abrir PR — é o gate de avanço** |
| `revisar-fase` · `instrumentar-e2e` · `escrever-testes` · `manter-docs-vivas` | sim | o ciclo do QA |
| `iniciar-feature` · `iniciar-bugfix` · `iniciar-hotfix` · `empilhar-prs` · `publicar-release` | sim | GitFlow por situação (a decisão de *começar* hotfix/release continua humana — está no corpo da skill) |
| `subir-supabase` | sim | a stack self-hosted enxuta, com a razão de cada serviço que fica de fora |

## DoD por etapa — a regra que governa o avanço

**Cada etapa do plano tem a sua própria Definition of Done, escrita antes de a etapa começar.** Não é uma seção no fim do documento: é uma lista por etapa, e ela é o que autoriza o avanço.

**O ciclo é fechado:** etapa implementada → **DoD verificada, rodando de verdade** → PR aberto → merge → próxima etapa. Sem DoD atingida não se abre PR, não se mergeia, e não se começa a etapa seguinte. "Acho que está pronto" não move nada.

**Toda linha do DoD é uma prova executável, de um destes três tipos:**

| Tipo | Como se prova |
|---|---|
| **Teste automatizado** | O teste existe, passa, **e falha sem a mudança**. Teste que nunca foi visto falhar não prova nada — verifique revertendo. |
| **Saída de comando** | O comando e a saída esperada, literais: `curl .../health` devolve `200` com `{"status":"ok"}`. Quem lê reproduz sem perguntar nada. |
| **Evidência de E2E** | Print ou log em `docs/NN-<nome>/evidencias/rodada_MM/`, com o `README.md` da rodada dizendo o que aquela imagem prova. |

**Escreva o DoD no nível do que a etapa promete, não do que é fácil medir.** Esta sessão custou três deploys quebrados porque o "pronto" do backend era *"os testes passam"* — e o que importava era *"o `/health` responde 200 no domínio"*. CI verde com serviço fora do ar é DoD mal escrito, não azar.

**O E2E entra no DoD da etapa que entrega comportamento visível ao usuário**, e é atestado pelo dev humano: o QA instrumenta, o humano confere os prints, a evidência fica na rodada. O roteiro exercita o que a etapa **promete**, não o caminho feliz — se a etapa corrige uma falha silenciosa, prova que cada modo de falha produz estado **visualmente distinto**.

**No PR, o DoD vai no corpo, com o resultado de cada linha.** É o que o revisor lê primeiro.

**Roadmap vivo (`docs/roadmap.md`).** Fonte única de rastreabilidade — o que foi feito, o que está em andamento, o que falta, **ordenado por dependência**, com status `[ ]` não iniciada · `[-]` em andamento · `[x]` concluída. **A tabela de decisões travadas do roadmap sobrepõe o `docs/plano.md`** onde os dois conflitarem: o plano é a intenção de origem, a decisão é o que ficou valendo. **Mantido atualizado pela IA** no fechamento de cada trabalho. Ao surgir item novo, a IA pode **reescrever o texto** para dar clareza e **reordená-lo** para o ponto de precedência correto. Decisão pendente do humano é **estado** e mora no roadmap, junto do item que a espera.

**A ordem das fases é uma decisão de produto, não de conveniência:** rotina vem antes de finanças. É a rotina que faz o app ser aberto todo dia e é o domínio mais barato para construir a máquina de ocorrência, estado terminal, log de eventos e notificação em dupla via. **Se a fase N não estiver em uso diário, não comece a N+1.**

## Autonomia — quando agir e quando parar

O humano pediu **o mínimo de interação**. Isso é autorização durável, não permissão para um passo só:

- **Siga sem perguntar** em tudo que é aditivo e reversível dentro do escopo do ganza: criar branch, abrir PR, escrever código e docs, criar recursos **novos** do ganza no Coolify, aplicar migration em banco local, marcar o roadmap.
- **Pare e pergunte** só quando: a ação toca recurso de **outro projeto** no servidor compartilhado (driva, love-secret, Garage, o próprio Coolify); é **destrutiva ou irreversível** (apagar volume, derrubar serviço alheio, aplicar migration em produção com dado real, `push --force`); ou exige **conta externa** dele (DuckDNS, Google/Firebase, Pluggy, cartão).
- **Decida sozinho** o que tem resposta óbvia ou é reversível de graça — e **registre a decisão** na tabela do `docs/roadmap.md` em vez de trazê-la para a conversa. Registro vale mais que pergunta: sobrevive à sessão.
- Quando parar for inevitável, **entregue tudo que não dependia da resposta primeiro** e pergunte uma coisa só.

## Ritmo de teste e paralelismo

**Rode teste escopado enquanto itera; a suíte inteira só nos pontos de consolidação.** Corrigindo um achado pontual, rode o arquivo de teste afetado. A suíte completa roda ao fechar um conjunto de mudanças, antes de um gate de revisão e antes de abrir PR. Numa iteração de agente o tempo dominante não é a execução do teste (segundos) — é o raciocínio e as chamadas de ferramenta. Rodar tudo a cada ajuste soma tempo de parede sem ganhar sinal.

**Meça antes de mexer em concorrência de teste.** `flutter test` e o Jest já paralelizam por padrão usando os núcleos disponíveis. Confirme o comportamento real (`--help`, docs) antes de configurar algo que provavelmente já está ligado — o gargalo raramente está aí.

**Paralelize implementação genuinamente independente.** Quando o trabalho se divide em partes que tocam arquivos disjuntos e não dependem do resultado uma da outra, dispare um agente por parte em vez de um agente fazendo tudo em fila. **Isole cada agente** (worktree próprio) quando eles vão escrever ao mesmo tempo. Consolide e **só então** rode a suíte completa na branch integrada. O que tem dependência real continua sequencial — não force paralelismo onde uma tarefa precisa do resultado da anterior.

**Duas escritas na mesma working directory se atropelam.** Com um agente rodando sem isolamento na pasta principal, não edite nada ali enquanto ele estiver ativo — nem mudança "sem relação" com o que ele faz. Ou espere, ou isole a sua também.

## Economia de tokens (obrigatório)

Custo de token é regra, não preferência. Duas ferramentas estão ativas neste repositório — **use-as**:

- **rtk** reescreve `git`/`grep`/`ls`/… via hook e enxuga a saída.
- **O grafo do CRG** (`.code-review-graph/`, ignorado pelo git) é atualizado por hook a cada `Edit`/`Write`. O repo está registrado com o alias **`ganza`**. Ele **só enxerga arquivo versionado**: código novo ainda não commitado não aparece no grafo — nesse caso, `Read` mesmo.

- **Grafo antes de grep/read cru.** Para explorar código, consulte primeiro os tools do MCP `code-review-graph` (`query_graph`, `get_review_context`, `detect_changes`, `semantic_search_nodes`, `get_impact_radius`). Só caia em `Grep`/`Read` quando o grafo não cobrir. (Vale para subagentes — inclua isso no prompt deles.)
- **Saída de comando enxuta.** Testes com `-r compact` (`flutter test -r compact`) e/ou `| tail`; nunca despejar log linha a linha.
- **`rtk proxy <cmd>` quando o filtro atrapalha.** O hook reescreve `grep`/`ls`/`git`… e embaralha saídas com números soltos. Precisa da saída crua? `rtk proxy grep -n …`.
- **Não reler** arquivo recém-editado (o harness rastreia o estado) nem redescrever o que já foi estabelecido.
- **Respostas diretas**: sem tabela decorativa nem recapitulação longa; o que muda a decisão do humano, e só.
- **Sessão nova a cada entrega.** Ao fechar um item do roadmap, **recomende ao humano iniciar uma sessão nova** — o roadmap e as docs vivas dão a continuidade, e o histórico acumulado (caro por reenvio) zera. Nunca no meio de uma tarefa. Junto, **entregue um "prompt de retomada" pronto para colar** em bloco de código: o próximo item do roadmap, os ponteiros vivos (`docs/NN-<nome>/`) e a **primeira ação concreta**.
  - **O prompt aponta, não recita.** É *self-contained* no sentido de não depender do histórico da conversa — **não** no de repetir o que já está no repo. Decisão travada mora no `plan.md`; estado de fase, no `roadmap.md`; regra de processo, aqui ou no `GITFLOW.md`; evidência, em `evidencias/`. Prompt de setenta linhas é sintoma: **o que ele carregava deveria ter virado texto no repo.**

## Git, branches e releases (GitFlow)

Fonte da verdade: **`docs/GITFLOW.md`**. Resumo operacional:

- **Ninguém comita direto em `main`/`develop`** — todo trabalho nasce num branch de suporte e volta por PR. `main` = produção (protegida, só recebe `release/*` e `hotfix/*`); `develop` = integração e base de todo trabalho.
- Nome de branch: **`feature/<issue>-<slug>`** (default), **`bugfix/<issue>-<slug>`**, **`hotfix/<issue>-<slug>`**, **`release/<vX.Y.Z>`**.
- **Regra de ouro:** `release/*` e `hotfix/*` voltam para **duas** branches (`main` **e** `develop`), com **tag SemVer** no merge em `main`. Merges de volta usam `--no-ff`.
- **CHANGELOG** (Keep a Changelog): a seção `Unreleased` é atualizada **no mesmo PR** da mudança.
- **Mais de um PR aberto ao mesmo tempo vai em PILHA** (stacked PRs), nunca vários PRs independentes contra `develop`. Ver `docs/GITFLOW.md` § 6 — inclusive a armadilha do filtro de branches do `ci.yml`.
- Por situação, use a skill: `iniciar-feature`, `iniciar-bugfix`, `iniciar-hotfix`, `empilhar-prs`, `publicar-release`.

## CI/CD e deploy (Coolify)

- **CI é a cancela** (`.github/workflows/ci.yml`): `dart format` + `flutter analyze` + `gates_guard.sh` + testes Flutter; `deno fmt`/`lint`/`check`/`test` nas functions; e **as migrations aplicando limpo num Postgres vazio** com gate de RLS e de política. Verde é pré-requisito de merge.
- **Monorepo: cada parte só builda quando muda.** No CI, um job `changes` (paths-filter) decide quais jobs rodam. No Coolify, cada deployável tem **`watch_paths`** (`app/**` quando a web entrar) — sem isso, mexer no app Flutter redeploya o backend à toa, e o servidor tem 2 vCPU dividido com outros dois projetos. **Deployável novo nasce com `watch_paths` configurado**; esquecer disso é o tipo de desperdício que ninguém percebe porque nada quebra.
- **Deploy = auto-deploy por branch** no **Coolify** (GitHub App). Deployáveis, domínios e variáveis: **`docs/deploy/coolify.md`**.
- **O Android não sai do Coolify.** O Coolify serve a stack Supabase e, mais tarde, a web; o APK é build local ou de CI, assinado fora do repo.
- **Segredo/URL/origem nunca no repo** — só env/Build Variable no Coolify. A URL da API do front é **compile-time** (`--dart-define-from-file`); o CORS do backend vem de `CORS_ORIGINS`.
- **Backup não é escopo** (decisão D4 do `docs/roadmap.md`, que sobrepõe o R9 e o §5.1 do plano). Não proponha rotina de `pg_dump`, não trate backup como item de DoD e não reabra o assunto — o humano já decidiu.
