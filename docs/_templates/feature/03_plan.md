# NNN - Nome curto da feature · Plano

> **Como usar este modelo.** Copie para `docs/NNN_<nome>/03_plan.md` e substitua
> tudo. As citações em blockquote (como esta) são instrução do modelo e **saem**
> do plano final; o resto é esqueleto para preencher. Os blocos marcados
> *Exemplo* são conteúdo ilustrativo — apague-os.
> `scripts/verify-gauntlet.sh` reprova o plano sem a seção `## Gauntlet` e sem
> cada um dos seis rótulos dela.
>
> **Todo link relativo aqui é escrito para resolver de `docs/NNN_<nome>/`, o
> destino da cópia — nunca da pasta do modelo.** Vizinho da feature é caminho
> nu (`02_specs.md`); coisa de `docs/` sobe um nível (`../roadmap.md`). O que só
> serve a quem preenche o modelo fica dentro de instrução como esta, que sai do
> plano final, e **não é escrito como link** — de dentro da pasta do modelo um
> caminho relativo da feature não resolve: vai como caminho a partir da raiz do
> repositório, em crase. O plano real vivo, para consultar a forma em tamanho
> natural, é `docs/001_cadastro_manual/03_plan.md`.

Fatiamento e execução. O "o quê" está em [`02_specs.md`](02_specs.md), o
contrato do pronto em [`01_prd.md`](01_prd.md), as decisões desta feature em
[`decisions.md`](decisions.md), os desvios em [`changes.md`](changes.md), e o
item canônico está no [`docs/roadmap.md`](../roadmap.md). **Este plano não
inventa escopo: ele distribui o DoD entre as fases e acrescenta o que falta
para cada fase se sustentar sozinha.**

Estado: **<fase e situação>** · branch `<branch>` (de `develop`) · <o que já
fechou> · **próximo passo: <ação concreta>**.

---

## Gauntlet

> Os seis rótulos abaixo são cobrados por `scripts/verify-gauntlet.sh`, por
> `grep` sobre o arquivo inteiro. Não os renomeie, não os traduza e não os
> transforme em heading.

**Referência:** [`01_prd.md`](01_prd.md), [`02_specs.md`](02_specs.md),
[`decisions.md`](decisions.md), [`changes.md`](changes.md), este plano,
`CLAUDE.md` e as decisões transversais em [`docs/decisions.md`](../decisions.md).

**Rubrica binária:** cada fase só passa quando contrato/DoD, arquitetura,
invariantes de produto e segurança estiverem `pass`.
Resultado subjetivo, impressão geral ou nota não são critérios de aprovação.

**Invariantes bloqueantes:** <as invariantes do `CLAUDE.md` que esta feature
toca de verdade — RLS comprovada, nenhuma credencial no cliente, dinheiro em
centavos inteiros, função com JWT do usuário, nenhuma gravação sem
confirmação>.

**Provas:** cada crítico devolve `pass` ou `fail`, evidência reproduzível,
arquivo/linha e ação corretiva. QA executa os comandos; CISO e crítico
integrador revisam sem editar a fatia implementada. A cada tarefa concluída, o
`supervisor-dod` julga o bloco DoD daquela tarefa, cego ao plano.

**Limites:** no máximo 3 rodadas e 45 minutos **por fase**. No nível da tarefa,
duas devoluções `NÃO CUMPRIDO` e a terceira escala ao humano; `DOD INVÁLIDO`
volta ao tech-lead, não reprova a tarefa e não consome essa cota. Depois de
consolidar tarefas paralelas, o crítico integrador revisa as dependências
cruzadas antes do fechamento.

**Evidência E2E:** não é escopo automatizado e não entra em DoD nenhum. Quem o
roda é o humano, quando quer revisar de fato (**D34** de `docs/decisions.md`, de
20/08/2026, revista em 21/08/2026). O automatizado do ganza é **unit + widget +
golden**. Não escreva linha de DoD que dependa de E2E, nem trate revisão humana
como etapa de rotina.

---

## 1. Decisões travadas antes de começar

> As decisões numeradas e seus impactos moram em [`decisions.md`](decisions.md);
> aqui fica só o ponteiro. Decisões globais continuam em
> [`../decisions.md`](../decisions.md). Desvio posterior é registrado em
> [`changes.md`](changes.md) **antes** da reconciliação deste plano.

---

## 2. Âncoras no código existente

> O que imitar, e onde. Levante pelo grafo do CRG antes de escrever o plano —
> não por leitura crua. Uma âncora útil diz o nome do arquivo, a forma a copiar
> e **o que não existe** (a ausência é o que mais custa quando é descoberta no
> meio da fase).

**App (`app/lib/`)** — <gabarito de módulo, forma do model, forma do estado,
onde registra DI e rota, o que não existe>.

**Backend (`supabase/functions/`)** — <roteamento, gabarito de função, tasks do
`deno.json`, como se publica>.

**Banco (`supabase/migrations/`)** — <última migration, formato literal da
política, convenções que o repo já segue>.

**CI (`.github/workflows/ci.yml`)** — <jobs, o que cada um roda, o filtro de
paths>.

---

## 3. Contrato fechado

> Schema, payload de endpoint ou contrato de tela — o que a feature fecha antes
> de começar, transcrito aqui **por extenso** para que a primeira fase não
> precise abrir outro documento. Fechado pelo PM ou pelo tech-lead: não
> reabrir; reabertura vira entrada em `changes.md`.

---

## 4. Ritual de fechamento de fase (vale para todas)

Escrito uma vez para não se repetir em cinco lugares. **Nenhuma fase avança sem
os quatro passos.**

1. O especialista dono implementa; `especialista-*` executa, o tech-lead não
   escreve código. A cada tarefa concluída, o `supervisor-dod` julga o bloco
   DoD daquela tarefa.
2. **QA roda `revisar-fase`** contra este plano e as regras do `CLAUDE.md`.
3. **CISO revisa o diff** da fase (sem `Write` — aponta, não conserta).
4. **`fechar-etapa` roda o DoD da fase, linha por linha, de verdade.** Só então:
   PR com o DoD no corpo e o resultado de cada linha → CI verde → merge em
   `develop` → próxima fase.

`CHANGELOG.md` (seção `Unreleased`) é atualizado **no mesmo PR** da mudança, em
toda fase.

---

## 5. Fases

> **Gramática da linha de tarefa** — uma linha, sem quebra de formato:
>
> ```
> - [ ] **T<fase>.<n>** `[paralela · frente A · worktree]` — <descrição imperativa com caminhos em crase> · camada **<camada>** · `<agente>`
> - [x] **T<fase>.<n>** — <descrição> · camada **<camada>** · `<agente>` · **DoD: CUMPRIDO**
> ```
>
> **O campo `DoD:` é o veredito do `supervisor-dod`**, escrito pelo orquestrador
> na própria linha assim que o supervisor se pronuncia: `CUMPRIDO`, `NÃO
> CUMPRIDO` ou `DOD INVÁLIDO`. Tarefa ainda não julgada não tem o campo, e **só
> `DoD: CUMPRIDO` autoriza marcar `[x]`**. O prefixo existe para o campo ser
> greppável sem ambiguidade — `grep -c 'DoD: CUMPRIDO'` não casa `DoD: NÃO
> CUMPRIDO` —, e é por ele que `revisar-fase`, `fechar-etapa` e o
> `critico-integrador` conferem, antes do PR, que nenhuma tarefa da fase ficou
> por julgar. Não existe artefato separado de veredito.
>
> A tag de paralelismo é opcional e sai quando a tarefa é sequencial. Camadas:
> `migration` · `backend` · `core` · `domain` · `data` · `presentation` ·
> `infra` · `docs` · `testes`. Depois do bloco de tarefas paralelas, escreva em
> prosa **por que** são paralelas ou sequenciais — duas escritas na mesma
> working directory se atropelam, e o custo do worktree nem sempre se paga.
>
> **A decomposição por frente vale nas fases finais também.** Teste
> automatizado, documentação e validação se fatiam por frente disjunta como
> qualquer outra fase. Fase de fechamento escrita como uma tarefa só, de um
> agente só, é fatiamento que não foi feito.
> ambiente — espera de parede); se as duas viram tarefas do mesmo agente ou de
> agentes diferentes, escreva a razão aqui, porque quem escreve o driver é quem
> melhor o depura quando a rodada falha.

### O bloco DoD da tarefa

> Logo abaixo de cada linha de tarefa, indentado por dois espaços, vem o bloco
> DoD daquela tarefa. Ele é além do DoD da fase, não no lugar dele.
>
> **Quem lê esse bloco não terá o plano em mãos.** O `supervisor-dod` é lançado
> a cada tarefa concluída e recebe só o bloco e um ponteiro para o trabalho —
> nunca o PRD, as specs, este plano, `decisions.md`, `changes.md` ou o relato do
> executor. Toda a régua abaixo existe por causa disso.
>
> **A régua, que é um teste mecânico:** apague todos os parênteses de
> referência; a linha ainda tem de se sustentar. Se a condição mora numa decisão
> numerada, **reescreva a condição por extenso** e cite a referência **depois**,
> como procedência — nunca como ponteiro a resolver.
>
> - **Não verificável** — *"A coluna de instante segue a decisão A3
>   (`decisions.md`)."* Apagado o parêntese, sobra *"segue a decisão A3"*: um
>   ponteiro para um documento que o supervisor não tem.
> - **Verificável** — *"A coluna de instante do lembrete é `timestamptz not
>   null`, nunca `timestamp` sem fuso (procedência: decisão A3 de
>   `decisions.md`)."* Apagado o parêntese, a condição continua inteira.
>
> **Quatro restrições, e a razão de cada uma:**
>
> 1. **Caminho completo a partir da raiz do repositório** — o leitor não sabe em
>    que módulo a tarefa mora. `app/lib/core/format/money_formatter.dart`, não
>    "o formatador".
> 2. **Cada linha diz como se prova**, num dos três tipos do `CLAUDE.md`: teste
>    automatizado que **falha sem a mudança** (verificado revertendo), saída de
>    comando **literal**. São dois tipos de prova, não três.
> 3. **Critério observável já ao fim da tarefa.** Nada que dependa de fase
>    futura, de merge, de CI do PR ou de aceite humano posterior — isso é DoD de
>    fase, e no bloco da tarefa vira `DOD INVÁLIDO`.
> 4. **Três a seis linhas.** Menos não cobre a tarefa; mais é DoD de fase
>    disfarçado.
>
> **Duas armadilhas que o bloco tem de cobrar quando se aplicam:** tarefa que
> mexe em documentação cobra que **nenhuma frase vizinha ficou falsa** depois da
> mudança, não só que a mudança foi registrada; e comando que a tarefa manda
> documentar é **executado copiado e colado**, não lido — documentação com
> comando que não roda é pior que documentação sem comando.

*Exemplo — apagar ao preencher:*

- [ ] **T1.1** — Criar `supabase/migrations/0007_criar_lembretes.sql` com a tabela `public.lembretes`, RLS ligada e política de dono, via skill `criar-migration`. · camada **migration** · `especialista-backend`

  **DoD da tarefa**

> **Não escreva linha de `dart format`, `flutter analyze` ou `gates_guard.sh`
> num bloco de tarefa.** Desde 21/08/2026 higiene de código é **DoD geral** —
> formatação aplicada e console limpo valem para toda entrega, sem estar escritos
> em lugar nenhum —, e a cancela roda na skill `fechar-etapa`, com o mesmo alvo
> que o `.github/workflows/ci.yml` usa. Gastar uma das três a seis linhas do
> bloco com isso tem dois custos: rouba a linha de uma prova que só aquela tarefa
> produz, e cria um alvo que **diverge** do CI — foi assim que a Fase 5 da
> feature 002 chegou ao gate final com dois arquivos de `test/` desformatados,
> invisíveis para seis supervisores que mediam só `lib/`.

  - `supabase/migrations/0007_criar_lembretes.sql` aplica limpo num Postgres vazio: `psql -v ON_ERROR_STOP=1 -f supabase/migrations/0007_criar_lembretes.sql; echo $?` imprime `0`. O `psql -q` do CI não imprime nada — quem prova é o código de saída, não a saída.
  - `psql -tAc "select rowsecurity from pg_tables where schemaname='public' and tablename='lembretes'"` devolve `t`.
  - `psql -tAc "select qual, with_check from pg_policies where tablename='lembretes'"` devolve exatamente uma linha, com `user_id = auth.uid()` nas duas colunas.
  - Com `set local request.jwt.claims = '{"sub":"<uuid do dono>","role":"authenticated"}'`, `select auth.uid()` devolve o uuid do dono e **não** `NULL`; só então: o `insert` **sem** esse `set local` é negado com `ERROR: new row violates row-level security policy for table "lembretes"`, e o `insert` do dono é aceito. A ordem importa — com `auth.uid()` nulo a negação passaria pelo motivo errado.
  - A coluna de instante do lembrete é `timestamptz not null`, nunca `timestamp` sem fuso, porque o mesmo `lib/` roda em Android e Web com fusos diferentes (procedência: decisão A3 de `decisions.md`).

*Exemplo de tarefa de apresentação — apagar ao preencher:*

- [ ] **T3.6** `[paralela · frente B · worktree]` — Criar `app/lib/modules/lembretes_module/presentation/lembretes_list/lembretes_list_cubit.dart` com estado `sealed` (`Loading`, `Loaded`, `Empty`, `LoadFailed`) via `part of`. · camada **presentation** · `especialista-apresentacao`

  **DoD da tarefa**
  - `app/lib/modules/lembretes_module/presentation/lembretes_list/lembretes_list_cubit.dart` existe, declara `sealed class LembretesListState` no mesmo arquivo via `part of`, com os quatro estados como `final class`, e nenhum `import` de `.../data/` aparece no arquivo.
  - Todo `emit` posterior a um `await` é precedido de `if (isClosed) return;` — conferir com `rtk proxy grep -n 'await\|isClosed\|emit' app/lib/modules/lembretes_module/presentation/lembretes_list/lembretes_list_cubit.dart`.
  - O `switch` sobre o estado cobre os quatro casos sem cláusula `default` — remover um `final class` do `sealed` faz `flutter analyze` acusar `non_exhaustive_switch`; provar rodando e restaurando.
  - Da raiz do repositório, `scripts/gates_guard.sh; echo $?` imprime `0`: nenhum literal de cor, espaçamento ou tipografia fora de `app/lib/core/theme/`, e nenhum método que retorne `Widget`.
  - O `switch` sobre o estado é exaustivo sem cláusula `default` — remover um `final class` do `sealed` faz `flutter analyze` acusar `non_exhaustive_switch`; provar rodando e restaurando.

### Fase 1 — <título curto> · PR 1

Branch: `feature/GZ-NN-<slug>`. <Por que esta fase vem primeiro e por que ela se
sustenta sozinha.>

**Tarefas**

- [ ] **T1.1** — <descrição> · camada **<camada>** · `<agente>`

  **DoD da tarefa**
  - <três a seis linhas, pela régua acima>

<Prosa: por que estas tarefas são paralelas ou sequenciais.>

**DoD da Fase 1**

> Texto bold, não heading. Cada linha é uma prova executável de um dos três
> tipos. Aqui **cabe** o que só existe depois da fase: job do CI verde no PR,
> atestado do dev humano sobre os prints, merge em `develop`.

- [ ] <prova, com comando e saída esperada literais>
- [ ] Job "<nome do job>" verde no CI do PR.

---

### Fase N — <título curto> · PR N

> Repita a forma acima por fase. A última fase — bateria automatizada,
> documentação viva e fechamento — **também** se decompõe por frente: ela não é
> uma tarefa só.

---

## 6. Rastreabilidade — as linhas do DoD do roadmap

> Uma linha por item do DoD que o `docs/roadmap.md` cobra desta feature, e a
> fase que fecha cada uma. É o que impede o plano de perder um requisito no
> fatiamento.

| # | Linha do DoD do roadmap | Fase que fecha |
|---|---|---|
| 1 | <linha literal do roadmap> | **<fase>** |

---

## 7. Riscos e dependências que o DoD do roadmap não cobre

> O que o roadmap não previu e que dói se ninguém escrever. Cada risco vira
> tarefa, vira linha de DoD, ou vira limitação **conhecida e aceita** com o
> lugar onde ficou registrada. Risco sem tratamento escrito não conta.

| # | Risco | Onde dói | Tratamento neste plano |
|---|---|---|---|
| X1 | <risco concreto, com a evidência de que é real> | <fase> | <tarefa, linha de DoD, ou aceite com o registro> |

---

## 8. Progresso

Legenda das fases: `[ ]` não iniciada · `[-]` em andamento · `[x]` mergeada em
`develop`. Na linha de **tarefa**, `[x]` significa outra coisa: veredito
`CUMPRIDO` do `supervisor-dod`, registrado no campo `DoD:` da própria linha.

- [ ] **Fase 1** — <título> · PR 1
- [ ] **Fase N** — <título> · PR N
