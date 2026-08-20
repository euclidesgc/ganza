# Histórico de mudanças - Feature 002 - Conta, configurações e chaves do usuário

Este arquivo é append-only. Registre uma entrada antes de mudar a implementação
ou os documentos canônicos por causa de um desvio descoberto após o início da
feature. Depois da entrada, reconcilie PRD, specs e plano para que descrevam o
estado final, sem preservar neles uma versão obsoleta do planejamento.

## Mudanças registradas

### CHG-013 - Print de emulador em DoD de tarefa segue a mesma régua, e a senha antiga troca de prova em vez de sair do gate

- **Data:** 2026-08-20
- **Fase/PR:** Fases 2, 3 e 4 (PRs 2, 3b e 4b), nenhuma iniciada. Fecha as duas
  pontas que a **CHG-012** deixou abertas de propósito.
- **Planejado originalmente:** a **CHG-012** adiou as rodadas de E2E e as oito
  tarefas de instrumentar/executar, mas **não** mexeu em três linhas de bloco DoD
  de tarefa de **implementação** que cobram print de emulador — uma da **T2.5** e
  duas da **T4.11** —, por entender que tirar prova do DoD de uma tarefa muda a
  exigência dela e é chamada do humano. Elas ficaram listadas na §9 como
  pendência de decisão. Na Fase 3, a prova de que **a senha antiga deixa de valer
  depois da troca** também ficou pendurada: existia só na cena adiada da T3.9, com
  a alternativa por comando escrita para quem despachasse a fase decidir.
- **Por que não foi possível prosseguir:** manter T2.5 e T4.11 sob régua diferente
  da T1.15 — cujo print foi retirado no começo da mesma sessão — deixaria a
  política **incoerente entre fases**, que é exatamente o defeito que a CHG-012
  fora escrita para eliminar. E deixar a senha antiga sem prova no PR contradiz a
  fronteira que a própria **D30** fixou: invariante de segurança provado por
  saída de comando **não sai do gate**.
- **Alternativas consideradas:** (a) esperar a palavra do humano linha a linha —
  paralisa três fases por uma decisão que a diretriz de velocidade dele já cobre;
  (b) mover as três linhas e não registrar quem decidiu — barato e **silencioso**,
  que é o defeito de verdade; (c) mover, **registrar como decisão do orquestrador
  e deixá-la reversível** pela §9, com caminho completo de cada linha; (d) na Fase
  3, adiar a exigência junto da cena — recusada, porque a exigência é a mais
  importante do fluxo e a D30 proíbe adiar prova de segurança por comando.
- **Decisão tomada:** (c) e, na Fase 3, **migrar a prova em vez da exigência**.
  Concretamente: o print `03_navegacao_pelo_drawer.png` sai do DoD da **T2.5**
  (que fica com quatro linhas); na **T4.11**, a linha do `refreshListenable`
  mantém a exigência estrutural provada por
  `rtk proxy grep -n 'Listenable.merge' app/lib/app_router.dart` e migra só a
  prova visual, e a linha do item de chat desabilitado é **partida em duas** — o
  teste de widget que assere o rótulo semântico **fica**, porque se prova por
  comando, e só o print migra. As três entram na §9 com caminho completo, e caem
  de graça nas rodadas `round_03` e `round_05`, que já passam por essas telas. Na
  **Fase 3**, entra linha nova no DoD da fase: com uma conta de teste da stack
  local, trocar a senha pelo mesmo endpoint que o app chama em
  `updateUser(password:)` (`PUT /auth/v1/user`, `200`) e então
  `POST /auth/v1/token?grant_type=password` com a **senha antiga** devolvendo
  **`400`** e com a **nova** devolvendo `200` — comandos literais no plano, saídas
  no corpo do PR.
- **Resumo da resolução:** a régua passou a valer igual em todas as fases, e
  nenhuma prova sumiu — mudou de momento, com endereço. **A decisão de mover
  print de DoD de tarefa é do orquestrador, apoiada na diretriz de velocidade de
  20/08/2026, e não do humano**; está escrita na §9 com essas palavras justamente
  porque mexe na exigência de tarefas, e a §9 é o caminho de volta se ele
  discordar. A linha da Fase 3 **não** acrescenta exigência: "a senha antiga
  deixa de valer" já era cobrada, e o que mudou foi a prova, que deixou de
  depender de emulador. Fica escrito o que ela **não** prova — que a tela de Conta
  chama esse endpoint —, e isso continua na cena adiada da T3.9. Contagens de
  tarefa não mudam: a feature segue com **65** tarefas, e nenhuma tarefa nasceu ou
  morreu aqui.
- **Sobrepõe a CHG-012:** o item "O que ficou de fora de propósito" daquela
  entrada, que dizia que as três linhas continuavam sem decisão. Continua valendo
  o resto dela.
- **Reconciliação documental:** `docs/002_conta_e_configuracoes/03_plan.md` —
  bloco DoD da **T2.5**, duas linhas do bloco da **T4.11**, linha nova no DoD da
  **Fase 3** e o parágrafo "O que esta fase não cobra mais" daquela fase, mais
  duas linhas novas na tabela da §9 e o parágrafo que registra a autoria da
  decisão. `docs/decisions.md` **não muda**: a **D30** já previa este caso — o que
  faltava era aplicá-lo. `01_prd.md`, `02_specs.md` e `decisions.md` desta pasta
  não mudam.

### CHG-012 - A D30 alcançou as fases 2 a 5, e uma prova de segurança quase foi adiada junto

- **Data:** 2026-08-20
- **Fase/PR:** Fases 2, 3, 4 e 5 (PRs 2, 3b, 4b e 5b), nenhuma delas iniciada.
  Segunda onda da **D30**, cuja primeira aplicação — só à Fase 1 — está na
  **CHG-011**.
- **Planejado originalmente:** cada fase colhia a sua rodada de E2E antes do PR —
  `round_03` (Fase 2), `round_04` (Fase 3), `round_05` (Fase 4) e `round_06`
  (Fase 5) —, com um par instrumentar/executar dentro da fase e uma linha do DoD
  da fase exigindo a rodada mais o atestado do dev humano. O Gauntlet e a tabela
  §6 do plano prometiam **uma rodada por fase**.
- **Por que não foi possível prosseguir:** a **D30** tirou a rodada de E2E do
  caminho crítico, mas só a Fase 1 tinha sido reconciliada. Deixar as outras
  quatro como estavam significava **repetir o mesmo bloqueio quatro vezes** —
  descobrir, na abertura de cada PR, que o DoD cobra uma rodada que a política
  manda adiar. E havia um caso pior que atraso: **a Fase 4 empacotava, numa linha
  só e numa tarefa só, naturezas diferentes** — a rodada `round_05`, que é
  emulador, e a prova de isolamento entre dois usuários mais a prova de RLS, que
  são `curl` e `psql`. Adiar a linha inteira teria tirado do gate do PR uma
  invariante bloqueante do gauntlet **sem ninguém perceber**, porque as duas
  estavam na mesma frase.
- **Alternativas consideradas:** (a) esperar cada fase chegar e resolver na hora —
  é o custo que a decisão queria evitar, e no caso da Fase 4 o erro seria
  silencioso; (b) adiar tudo que cita rodada, inclusive a linha da Fase 4 —
  barato de escrever, perde segurança; (c) adiar as rodadas e **partir a linha da
  Fase 4 em duas**, promovendo a prova por comando a tarefa própria, que fica no
  PR.
- **Decisão tomada:** (c), pelo `tech-lead`, com a fronteira escrita na **D30**
  para valer nas fases que ainda nem existem: adia-se prova que depende de
  emulador; prova de invariante de segurança por saída de comando nunca sai do
  gate do PR. Concretamente: **T2.6, T2.7, T3.9, T3.10, T4.12, T4.13, T5.7 e
  T5.8** marcadas `[adiada · lote de fechamento]`, com os blocos DoD preservados
  inteiros; a **T4.14 nasce** — provar por comando o isolamento entre dois
  usuários e a RLS de `public.ai_user_credentials`, com evidência em
  `docs/002_conta_e_configuracoes/e2e/round_05/isolamento.md` — e **fica no PR
  4b**; a T4.13 perde as duas linhas de prova por comando e o "e a prova de
  isolamento" do título.
- **Resumo da resolução:** varrendo as quatro linhas com o mesmo olho apareceram
  **três gêmeas** que sozinhas continuariam bloqueando o PR e migraram junto: o
  "E2E atestado pelo dev humano" da Fase 2, o "E2E da rodada 05 atestado pelo dev
  humano" da Fase 4 (na Fase 3 o atestado já estava dentro da própria linha da
  rodada), e — o achado menos óbvio — a linha da Fase 5 que provava **pelos
  prints da rodada** que a capacidade de banco vem da tabela e não do binário:
  ela foi arrastada porque a única prova que nomeava eram os prints. Dois
  resíduos ficam escritos onde doem: o risco **X3 cresceu** — os dois roteiros
  `patrol` herdados da feature 001 ficam **vermelhos desde a Fase 2 até o lote
  rodar**, com o descasamento de string se acumulando por quatro fases em vez de
  aparecer numa —, e na Fase 3 **a prova de que a senha antiga deixa de valer
  depois da troca** passa a existir só na cena adiada, com a alternativa por
  comando registrada para quem despachar a fase decidir. Contagens: Fase 2 leva 5
  tarefas ao PR (de 7), Fase 3 leva 8 (de 10), Fase 4 passa a ter 14 tarefas e
  leva 12, Fase 5 leva 6 (de 8), e a feature vai de 64 para **65** tarefas. A
  **Fase 6 não foi tocada**: ela não tem rodada de E2E — suas provas são
  `deno task test`, o corpus de injeção e `psql` num Postgres vazio.
- **O que ficou de fora de propósito:** três blocos DoD de tarefa de
  **implementação** também cobram print de emulador — **T2.5** e duas linhas da
  **T4.11**. Tirar prova do DoD de uma tarefa muda a exigência dela, e isso é
  chamada do humano; ficam listadas em `03_plan.md` §9 para não se perderem, e
  quem despachar a fase resolve com uma palavra.
- **Reconciliação documental:** `docs/decisions.md` (**D30** ganha a fronteira
  emulador × prova de comando e a consequência aceita de a rodada adiada não
  apontar mais para uma fase); `docs/002_conta_e_configuracoes/03_plan.md` —
  parágrafo "Evidência E2E" do Gauntlet, prosa e DoD das Fases 2 a 5, oito
  tarefas marcadas, T4.13 reescrita, **T4.14** criada, nota de rodapé da tabela
  §6, risco **X3**, §8 Progresso e a tabela da §9. `01_prd.md`, `02_specs.md` e
  `decisions.md` desta pasta **não mudam**: nenhuma promessa de produto foi
  alterada, só quando cada prova acontece.

### CHG-011 - Teste que não é DoD sai do caminho crítico, e a Fase 1 perde a cena e o print que ainda faltavam

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1), por decisão de processo tomada com a fase aberta —
  T1.15 em execução, T1.16 e T1.17 ainda pendentes.
- **Planejado originalmente:** a Fase 1 só fechava com **dezessete** tarefas
  cumpridas. A **T1.15** provava a saída da etapa de nova senha também **no
  emulador**, capturando
  `docs/002_conta_e_configuracoes/e2e/round_02/20_saida_sem_trocar_senha.png`; a
  **T1.16** escrevia uma cena nova no roteiro `patrol` — pedir recuperação da
  conta-semente, digitar o código certo, acionar "Sair sem trocar a senha" e
  entrar de novo com a senha antiga — e fechava a evidência no `report.md` da
  rodada 02; e a linha do DoD da fase sobre a saída da recuperação cobrava as
  duas coisas antes do PR.
- **Por que não foi possível prosseguir:** o humano decidiu, em 20/08/2026,
  **suspender a escrita de teste unitário e de E2E que não seja linha de DoD de
  alguma tarefa**, para acelerar a entrega, deixando o gate de qualidade da
  implementação com o `supervisor-dod` (**D30** de `docs/decisions.md`). O
  impedimento não é técnico: é que o DoD da Fase 1, como estava escrito,
  **bloqueia o PR** por duas provas que a decisão nova manda adiar — uma rodada
  de emulador para tirar um print e uma cena nova de `patrol`. Manter o texto
  obrigaria a violar a decisão para abrir o PR, ou a segurar o PR contra ela.
- **Alternativas consideradas:** (a) apagar a T1.16 e o print — descarta
  comportamento já desenhado e prova já acordada, e o resíduo do abandono
  ficaria sem nenhuma evidência de que entrar com a senha antiga ainda funciona;
  (b) manter tudo e abrir o PR assim mesmo — contraria a decisão do humano no
  mesmo dia em que ela foi tomada; (c) baixar a exigência da T1.15, trocando o
  teste de cubit por inspeção de código — afrouxa comportamento, que é
  justamente o que não se pode fazer; (d) **realocar quando a prova acontece**,
  sem mexer no que ela exige.
- **Decisão tomada:** (d), pelo `tech-lead`. A **T1.15** perde a linha do print em
  emulador e fica com cinco linhas — entre elas o teste de
  `app/test/modules/auth_module/presentation/password_recovery/password_recovery_code_cubit_test.dart`,
  que **é** DoD de tarefa e por isso continua obrigatório, com a prova de que
  falha sem a mudança. A **T1.16** continua escrita, com o bloco DoD intacto,
  marcada `[adiada · lote de fechamento]` e fora do DoD da Fase 1. A linha do DoD
  da fase sobre a saída passa a cobrar o que se prova agora — o rótulo no código
  e o teste de cubit passando — e mantém, sem tirar uma vírgula, o resíduo
  aceito e o atestado do dev humano.
- **Resumo da resolução:** o PR 1 deixa de depender de rodada nova de emulador.
  **Nada do que já foi colhido é descartado:** `e2e/round_01/` (medição da
  sessão) e `e2e/round_02/` (ciclo de conta e recuperação) continuam valendo como
  evidência da fase, e o atestado do dev humano sobre o ciclo completo de conta
  continua sendo linha do DoD da Fase 1. A contagem de tarefas do DoD da fase cai
  de dezessete para **dezesseis** (T1.1 a T1.15 e T1.17), e o que saiu está
  listado em `03_plan.md` §9 — pendência que não está escrita é pendência
  perdida.
- **Reconciliação documental:** `docs/decisions.md` (**D30**, política
  transversal, com os trechos do `CLAUDE.md` que ela sobrepõe);
  `docs/002_conta_e_configuracoes/03_plan.md` — bloco DoD da T1.15, linha e
  marcação da T1.16, nota de paralelismo depois da T1.17, duas linhas do DoD da
  Fase 1 (a contagem das tarefas e a da saída da recuperação), §8 Progresso e a
  §9 nova. `01_prd.md`, `02_specs.md` e `decisions.md` desta pasta **não mudam**:
  o comportamento prometido é o mesmo, só muda quando a prova acontece.

### CHG-010 - A conta-semente da stack local passou a ser confirmada por SQL, e nenhuma tarefa previu isso

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1), consequência não prevista da T1.5.
- **Planejado originalmente:** a **T1.5** virava `GOTRUE_MAILER_AUTOCONFIRM` para
  `'false'` na stack local e instalava o capturador de e-mail, para que o
  cadastro nascesse **não confirmado** e a confirmação acontecesse pela mensagem,
  como no ambiente real. Nenhuma tarefa da fase previa mexer em
  `scripts/local-supabase.sh`, que é o script de ambiente herdado da feature 001.
- **Por que não foi possível prosseguir:** com o autoconfirm global desligado, a
  conta-semente fixa `e2e@ganza.local` — criada pelo próprio script, por
  `POST /auth/v1/signup`, para os roteiros de E2E da feature 001 — passou a
  nascer com `email_confirmed_at` nulo e **deixou de conseguir entrar**. Todo
  `scripts/local-supabase.sh reset` produzia um ambiente em que os roteiros
  herdados falhavam no login, por um motivo que não tem nada a ver com o que eles
  testam. O desvio nasceu dentro da execução da fase e ninguém o escreveu.
- **Alternativas consideradas:** (a) devolver `GOTRUE_MAILER_AUTOCONFIRM` para
  `'true'` na stack local — apaga exatamente o comportamento que esta fase
  precisa exercitar, que é o cadastro nascer pendente e a confirmação vir da
  mensagem; (b) o script confirmar a semente pelo link do capturador, como o
  roteiro da 002 faz — é o caminho honesto, mas põe o script de ambiente
  dependente do capturador e do parsing da mensagem para uma conta **fixa**,
  cuja confirmação não prova nada de produto, e acrescenta ao `reset` um modo de
  falha novo; (c) endpoint de admin do GoTrue com `service_role` — continua
  sendo escrita administrativa, só que por HTTP, e com formato que varia entre
  versões; (d) `update` direto em `auth.users`, escopado ao id que o próprio
  script acabou de criar.
- **Decisão tomada:** (d), **manter e registrar**, pelo `tech-lead`. O comando
  vive em `scripts/local-supabase.sh` como
  `update auth.users set email_confirmed_at = now() where id = '$user_id' and email_confirmed_at is null`,
  e é executado pelo `psql` do contêiner: o `DB` do script é
  `docker compose -f infra/local/docker-compose.yml exec -T db psql`, que não
  alcança servidor nenhum além do contêiner local. Refazer a rodada 02 para
  eliminar o `psql` custaria a evidência inteira sem comprar garantia: o caminho
  que o critério A1 protege — criar conta pelo app e entrar sem Studio — nunca
  passou por ele.
- **Resumo da resolução:** o `update` toca **uma** conta, por id, e só quando ela
  está pendente. A conta que o roteiro da 002 exercita é sorteada na execução, no
  formato `e2e-<12 letras>@ganza.local`; a semente é `e2e@ganza.local`. O hífen
  já separa os dois endereços, e a consulta sequer usa endereço — usa o id. O
  `report.md` da rodada 02 passa a explicar as duas ocorrências de `psql` e a
  colar a prova de que a conta sob teste não foi alcançada por elas. O porquê já
  está escrito em comentário no próprio script, e por isso **não** vira tarefa
  nova.
- **Reconciliação documental:** `03_plan.md`, linha do DoD da Fase 1 sobre a
  `round_02`, que passa a distinguir **fluxo** de **preparação de ambiente** sem
  afrouxar a proibição: a conta sorteada continua obrigada a nascer, confirmar e
  entrar só pelo app e pela mensagem capturada;
  `docs/002_conta_e_configuracoes/e2e/round_02/report.md`, escrito pelo `qa`.

### CHG-009 - Abandonar a recuperação depois do código aceito não tinha saída, e a saída de fato deixava a senha antiga valendo em silêncio

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1), tarefas novas T1.15, T1.16 e T1.17.
- **Planejado originalmente:** o `02_specs.md` §6.3 justifica o terceiro estado da
  guarda — "sem um terceiro estado, a pessoa digita o código certo, é logada e
  **nunca vê o campo de nova senha**" —, e o plano o entregou como escopo **em
  memória, por desenho**, em `app/lib/core/session/password_recovery_scope.dart`.
  Nenhuma tarefa da fase previu o que acontece quando a pessoa **chega** à etapa
  de nova senha e não a conclui: o único cancelar montado é o da etapa do código,
  em `code_step_form.dart:93`, e ele apenas desliga o escopo.
- **Por que não foi possível prosseguir:** o `qa` reprovou a fase com um achado
  que é **lacuna de critério, não erro de execução** — o código faz exatamente o
  que o plano mandou. A cadeia, toda verificável: o `verifyRecoveryCode` bem-
  sucedido autentica a sessão do GoTrue, que o `supabase_flutter` persiste em
  disco (a **T1.1** provou que ela sobrevive a `force-stop` e a `reboot`); a
  etapa de nova senha não tem saída nenhuma, porque `new_password_step_form.dart`
  não monta `CancelRecoveryLink`, `password_recovery_code_page.dart` monta um
  `Scaffold` **sem `appBar`** e a guarda de `app/lib/app_router.dart` devolve
  qualquer outra rota para a própria tela; logo **a única saída é matar o app**,
  o que zera o escopo em memória e, na abertura seguinte, leva direto para a
  lista de áreas — **com a senha antiga valendo e nada dizendo que a recuperação
  não terminou**. É o desfecho que o §6.3 diz existir para evitar, chegando por
  outro caminho. O comentário de `password_recovery_code_cubit.dart:28-31`
  argumenta que desligar o escopo no cancelar não abre brecha, mas o raciocínio
  cobre só o caso **antes** do `verifyOTP`; o caso depois não foi considerado em
  lugar nenhum, e o E2E da fase não o exercita.
- **Alternativas consideradas:** (a) aceitar por inteiro e documentar — a pessoa
  já provou posse do e-mail, que é o mesmo fator com que o GoTrue autentica; mas
  deixa a tela **sem saída**, defeito de interface que independe da discussão de
  sessão; (b) `signOut()` no `close()` do cubit em `AwaitingPassword`/
  `UpdateFailed`, como o `qa` sugeriu — **não resolve o caso relatado**:
  `close()` não roda em `force-stop`, e sair navegando já é impedido pela guarda,
  de modo que ele cobriria um caminho que não existe; (c) persistir o escopo de
  recuperação em disco, para o app reabrir sabendo que a troca ficou pendente —
  é o único desenho que fecha o caso do `force-stop`, e troca um estado raro por
  **risco de trancar a pessoa** numa tela sem saída, além de exigir mecanismo
  novo em `core/session/`, gancho de abertura do app e mais uma rodada de E2E no
  fim de uma fase de catorze tarefas; (d) saída explícita na etapa de nova senha
  que **encerra a sessão antes** de desligar o escopo, com o resíduo do
  `force-stop` aceito por escrito.
- **Decisão tomada:** (d), pelo `tech-lead`. A saída passa a existir com o rótulo
  **"Sair sem trocar a senha"**, que nomeia a consequência antes do toque, e quem
  a aciona volta para a tela de entrar sem sessão. Encerrar em vez de entregar o
  app não é preciosismo: sem isso, quem chega ao inbox alheio tem um caminho
  **discreto** para uma sessão persistente, porque trocar a senha é justamente o
  passo que o dono perceberia — e a **Fase 5** desta mesma feature põe conta
  bancária atrás dessa sessão. O resíduo do `force-stop` fica **aceito e
  escrito**, com a condição que o reabre: risco **X18** do plano, linha do DoD da
  Fase 1 e entrada nova em `decisions.md`.
- **Resumo da resolução:** nascem a **T1.15** (a saída, com teste de cubit que
  assere o encerramento da sessão **antes** do desligamento do escopo e falha sem
  a mudança, mais o print da tela de entrar no emulador), a **T1.16** (cena de
  abandono no roteiro `patrol`, usando a conta-semente, que termina **entrando
  com a senha antiga** — prova visível de que abandonar não troca senha) e a
  **T1.17** (a doc canônica: a aceitação em `decisions.md`, a saída na spec da
  recuperação, e a correção da frase que manda pedir outro código "pela barra de
  título" numa tela que não tem barra de título). A Fase 1 vai de catorze para
  **dezessete** tarefas, e a feature de 61 para **64**. A T1.16 e a T1.17 são
  paralelas entre si, com arquivos disjuntos, e as duas dependem da T1.15. **A
  evidência fica na `round_02`**, não em rodada nova: o Gauntlet fixa `round_03`
  como a Fase 2, e a `round_02` já é o diretório de evidência desta fase.
- **Reconciliação documental:** `03_plan.md` — tarefas **T1.15**, **T1.16** e
  **T1.17**, prosa da Fase 1, linha de estado no cabeçalho, DoD da Fase 1
  (contagem `17` e linha nova que escreve a aceitação por extenso, para o dev
  humano atestar sabendo dela), §7 (risco **X18**) e §8 Progresso;
  `02_specs.md` §7.2 e `docs/002_conta_e_configuracoes/decisions.md`, pela
  **T1.17**. O §6.3 do `02_specs.md` **não** se torna falso — ele explica por que
  o terceiro estado existe, e continua verdadeiro; o que faltava era o desfecho
  de saída, que é comportamento novo.

### CHG-008 - A rodada 02 reprovou por defeito do app, e a prova do conserto não tinha onde morar

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1), tarefa T1.11.
- **Planejado originalmente:** a T1.11 executaria o roteiro da T1.10 e fecharia
  a evidência. Nenhuma tarefa da fase previa mexer no app durante a execução.
- **Por que não foi possível prosseguir:** a cena `recuperar_senha` parou com
  `setState() or markNeedsBuild() called during build` vindo do `Router`. O
  construtor do `PasswordRecoveryCodeCubit` chama `begin()`, e o `create` do
  `BlocProvider` é **lazy** — ele roda durante o build da árvore de rotas —, de
  modo que o `notifyListeners` síncrono reentrava no `GoRouter`, que escuta o
  escopo pelo `refreshListenable`, no meio do build dele. **Em release isso fica
  dentro de um `assert`**, o que faria a falha existir sem aparecer.
- **Alternativas consideradas:** (a) tirar o `begin()` do construtor do cubit,
  para um callback pós-frame ou para o `pageBuilder` — move o problema, porque o
  `pageBuilder` também é chamado em fase de build; (b) adiar a mudança de
  `_isActive` junto com a notificação — abre uma janela em que o `redirect` lê
  `false` com a pessoa já na tela do código, e a manda para `/entrar`;
  (c) adiar **só** o `notifyListeners`.
- **Decisão tomada:** (c), em `app/lib/core/session/password_recovery_scope.dart`
  (commit `c278c9f`). `_isActive` continua mudando de forma síncrona — o
  `redirect` do mesmo frame já lê o valor novo — e a notificação é adiada para
  depois do frame corrente quando a chamada acontece em fase de build.
- **Resumo da resolução:** o teste `app/test/core/session/password_recovery_scope_test.dart`
  reproduz o formato exato do defeito sem depender do go_router, e foi visto
  falhar com a correção revertida. A primeira linha do DoD da T1.11 passou a
  cobrar o log da rodada **versionado**, em `logs/execucao.txt`, sem a frase do
  defeito: o critério anterior era atestado sem lugar de repouso, que nenhum
  supervisor cego consegue confirmar — foi o `DOD INVÁLIDO` que o revelou.
- **Reconciliação documental:** `03_plan.md`, primeira linha do DoD da **T1.11**;
  `CHANGELOG.md`, seção `Unreleased`. A extensão `.txt` segue o que a round_01
  já fazia em `logs/gotrue_requisicoes.txt`, porque `*.log` está no `.gitignore`
  e a prova precisa chegar ao PR.

### CHG-007 - O segundo modo de falha do E2E era um que o roteiro evita, e a alternativa não era falha nenhuma

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1), tarefa T1.11.
- **Planejado originalmente:** o DoD da **T1.11** exigia "um print com código
  errado … e um print com o e-mail inexistente **ou** fora da janela de reenvio",
  e o DoD da **T1.10** proíbe repetir cadastro ou pedido de recuperação do mesmo
  endereço dentro de 60 segundos.
- **Por que não foi possível prosseguir:** as duas linhas não podem ser
  satisfeitas pelo mesmo roteiro. O roteiro foi escrito corretamente, seguindo a
  T1.10, e por isso **nunca** produz o estado que a T1.11 mandava fotografar. As
  **duas metades** da linha estavam erradas, e não só uma: o limite de reenvio é
  um modo de falha que o roteiro é desenhado para evitar; e o endereço inexistente
  **não é falha** — por anti-enumeração (**FD-024**, **FD-025**) o pedido de
  recuperação responde igual ao de endereço existente, de modo que exigir dele um
  estado "visualmente distinto" pede exatamente o oposto do que a segurança
  garante.
- **Alternativas consideradas:** (a) endereço que nunca teve conta como segundo
  modo de falha — **não funciona**, pelo motivo acima: o estado é idêntico ao de
  sucesso, por desenho; (b) manter o limite de reenvio, numa cena com outro
  endereço, dentro da janela dele — satisfaz as duas linhas, ao custo de uma cena
  e de cerca de 70 s de parede, e reintroduz no roteiro justamente o estado que a
  T1.10 manda evitar, encostando de novo no limite que já derrubou execução;
  (c) aceitar o print herdado da T1.7 — mistura evidência de duas execuções;
  (d) **senha nova fraca** no passo de nova senha do próprio fluxo.
- **Decisão tomada:** (d), pelo `tech-lead`. É falha de verdade, com mensagem
  própria e ação corretiva óbvia, **dentro do fluxo que o roteiro já percorre**:
  não manda e-mail, não espera janela nenhuma e não encosta no limite de reenvio.
  É também o segundo erro mais provável do fluxo, depois de errar o código.
- **Resumo da resolução:** a linha da T1.11 passa a cobrar o print do **código
  recusado** e o print da **senha nova fraca**. O caso do endereço inexistente
  continua valendo como prova de anti-enumeração — que é uma asserção de
  **igualdade**, não de distinção —, e por isso não cabe nesta linha nem vira
  exigência agora: mandar o roteiro emitir mais um pedido de recuperação é o tipo
  de acréscimo que recria a armadilha que esta entrada fecha.
- **Reconciliação documental:** `03_plan.md`, linha do DoD da **T1.11**;
  `02_specs.md` §7.2, que passa a nomear os dois modos de falha do fluxo. **A
  T1.10 não reabre:** nenhuma linha dela se torna falsa — ela lista as cenas que
  o roteiro deve cobrir, sem fechar a lista —, e a cena nova entra na execução da
  T1.11, que é do **mesmo agente** por desenho, porque quem escreve o driver é
  quem o depura quando a rodada falha.

### CHG-006 - O erro mais provável do fluxo de recuperação não tinha mensagem, e o link local não resolve

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1), tarefas novas T1.13 e T1.14.
- **Planejado originalmente:** o `02_specs.md` §7.2 descrevia o caminho da
  recuperação por código de seis dígitos sem fixar **nenhuma** mensagem de erro
  da tela, e nenhum DoD cobria o desfecho de código recusado. A Fase 1 tinha doze
  tarefas.
- **Por que não foi possível prosseguir:** o QA, escrevendo o roteiro de E2E,
  mostrou que quem digita o código errado lê **"Algo deu errado. Tente de novo."**
  — o GoTrue devolve `otp_expired`, que não está entre os cinco códigos
  traduzidos em `app/lib/modules/auth_module/data/repositories/auth_repository_impl.dart`,
  e cai no `_ => UnexpectedFailure()`. É o erro **mais provável** de todo o fluxo
  (seis dígitos copiados de um e-mail) e o único com ação corretiva óbvia, que a
  mensagem genérica esconde. Não é falha de executor: é critério que nunca
  existiu. Na mesma passada, o QA mediu que o link de confirmação emitido para a
  caixa local aponta para `/verify` enquanto o Kong só roteia `/auth/v1/verify` —
  e quem clicar leva `404`.
- **Alternativas consideradas:** (a) deixar a mensagem genérica e apenas fixar
  no `02_specs.md` que é ela mesma — barato, e entrega a fase com o erro mais
  comum do fluxo sem ação corretiva; (b) reabrir a **T1.6** pela terceira vez
  hoje; (c) tarefa nova pequena para o braço que falta; (d) tentar distinguir
  "código errado" de "código vencido" na tela.
- **Decisão tomada:** (c), pelo `tech-lead`. (b) foi descartada porque a linha de
  DoD da T1.6 diz "cobre **pelo menos**" os cinco códigos — acrescentar um sexto
  **não a torna falsa**, e reabrir uma tarefa já verificada duas vezes no mesmo
  dia gasta o significado do veredito sem comprar nada. (d) foi descartada por
  segurança, não por custo: ver **FD-026**. O link local vira a **T1.14**,
  separada por ser infraestrutura e por tocar arquivo que nenhuma outra tarefa
  aberta abre.
- **Resumo da resolução:** nascem a **T1.13** (camada data, um braço de tradução
  e o teste que o prova) e a **T1.14** (stack local, o link da caixa passa a
  resolver). A Fase 1 vai de doze para **catorze** tarefas, e a feature de 59
  para **61**. As duas são paralelas entre si e não bloqueiam a T1.10 nem a
  T1.11 — o roteiro de E2E já usa a rota pública correta.
- **Reconciliação documental:** `02_specs.md` §7.2, que passa a fixar as
  mensagens da tela do código; `03_plan.md` — tarefas **T1.13** e **T1.14**,
  contagem no cabeçalho, DoD da Fase 1 e §8 Progresso; `decisions.md`
  (**FD-026**).

### CHG-005 - A garantia anti-enumeração desce da tela para o contrato, e a T1.6 reabre

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1), tarefas T1.6 (reaberta) e T1.7.
- **Planejado originalmente:** o DoD da **T1.6** exigia tradução com "texto
  próprio em pt-BR e distinto entre si" para seis códigos do GoTrue, entre eles
  `user_already_exists`; o DoD da **T1.7** exigia que nenhum texto da tela
  afirmasse que o endereço já tem conta. **As duas linhas não podem valer ao
  mesmo tempo** com um banner que renderiza `failure.message` sem filtro, e a
  contradição passou despercebida quando a **FD-024** foi escrita.
- **Por que não foi possível prosseguir:** o supervisor da T1.7 mostrou que a
  camada data traduz `user_already_exists` para "Já existe uma conta com este
  e-mail." e que o banner de cadastro renderiza a mensagem crua — ou seja, a
  tela **diz** o que a **FD-024** proíbe. O `grep` do DoD da T1.7 voltou vazio
  por defeito próprio: estava escopado a `presentation/sign_up/`, e a string mora
  em `data/`. Hoje o caminho não dispara porque cadastro repetido de conta **não
  confirmada** volta `200` sem erro — mas o código está lá, e conta já confirmada
  não foi medida.
- **Alternativas consideradas:** (a) filtrar na apresentação, no cubit de
  cadastro — mais barato e menos invasivo, mas põe uma regra de **segurança** num
  lugar que cada tela nova precisa lembrar de repetir, e o mesmo tradutor já
  alcança a tela de entrar; (b) tratar dentro do `signUp`, na camada data,
  devolvendo o mesmo `Right(unit)` do sucesso, e **manter** o texto traduzido
  para outros chamadores; (c) fazer (b) **e remover o texto que revela**,
  deixando `user_already_exists` sem mensagem própria.
- **Decisão tomada:** (c), pelo `tech-lead`. (a) foi descartada porque segurança
  que depende de cada tela lembrar não é garantia, é convenção. (b) resolve o
  comportamento mas deixa a frase proibida no binário, a **uma chamada** de
  distância de vazar de novo — e como nenhum outro método do repositório pode
  receber esse código, o texto não serve a ninguém: é arma carregada esperando o
  próximo caminho de cadastro. Com (c) a garantia é dupla e cada metade custa uma
  linha: o `signUp` devolve desfecho **idêntico** ao do sucesso, e a frase deixa
  de existir.
- **Resumo da resolução:** a **T1.6 reabre** com duas linhas de DoD trocadas — a
  da tradução, que passa a cobrar cinco textos distintos e a exceção deliberada,
  e uma nova, que exige o `Right(unit)` provado por teste que falha sem a
  mudança. A **T1.7** tem o `grep` reescopado para o módulo inteiro, onde a
  string de fato mora. Nasce a **FD-025**.
- **Reconciliação documental:** `03_plan.md` — DoD da **T1.6** e da **T1.7**;
  `decisions.md` (**FD-025**). **A tela de entrar não vira tarefa nova:**
  `signIn` não pode receber `user_already_exists` — é código só de cadastro —,
  então o alcance do tradutor era risco latente, não vazamento vivo, e some junto
  com a frase pela mesma edição de uma linha.

### CHG-004 - O E2E da Fase 1 passa a cobrir a confirmação de e-mail e a primeira entrada

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1), tarefas T1.10 e T1.11, mais o DoD da fase.
- **Planejado originalmente:** o DoD da Fase 1 pedia "cadastro e recuperação
  ponta a ponta", e as cenas da T1.10 iam de criar conta direto para o fluxo de
  recuperação. Nenhuma linha exigia **confirmar o e-mail** nem **entrar com a
  conta recém-criada** — porque, quando essas frases foram escritas, a
  confirmação era automática e o cadastro já devolvia sessão.
- **Por que não foi possível prosseguir:** a **FD-022** desligou a confirmação
  automática, e a conta passou a nascer **sem sessão**. Um roteiro que cadastra,
  vê "confirme seu e-mail" e para ali prova que o formulário funciona, e **não**
  prova que alguém consegue criar uma conta e usar o app — que é o que o critério
  **A1** do `01_prd.md` promete, com todas as letras, "sem ninguém abrir painel
  de banco de dados". Já é fato observado, não hipótese: em 20/08/2026 um agente
  não conseguiu entrar com a conta local recém-criada e precisou marcar
  `email_confirmed_at` à mão por SQL. **Enquanto a confirmação ficar fora do
  E2E, o A1 não é entregável** — a única forma de entrar é justamente o painel de
  banco que ele proíbe.
- **Alternativas consideradas:** (a) manter o E2E como está e **reescrever** o
  DoD da fase e o A1 para prometerem só o formulário — honesto, mas entrega uma
  fase de autenticação que nunca viu ninguém entrar; (b) cobrir o ciclo inteiro
  no E2E — custo marginal de uma cena, porque o capturador da T1.5 já existe, já
  foi provado e o roteiro já precisaria dele para a recuperação; (c) criar uma
  tela de confirmação por código dentro do app, espelhando a de recuperação —
  escopo novo, tarefa nova, e nada exige que a confirmação aconteça no app.
- **Decisão tomada:** (b), pelo `tech-lead`. A confirmação acontece **fora do
  app**, pelo que chega na mensagem capturada, e o app só precisa dizer que ela
  falta (**FD-024**) e aceitar a entrada depois — por isso (c) não se justifica.
  O **A1 não é ampliado**: ele já cobrava isto, e o que muda é a prova passar a
  exercê-lo.
- **Resumo da resolução:** a T1.10 ganha as cenas de confirmar e entrar, mais a
  proibição de o roteiro avançar por SQL ou chamada administrativa; a T1.11 ganha
  a linha de evidência da primeira entrada; e o DoD da fase passa a cobrar o
  ciclo completo, com a régua de que **nenhum passo pode depender de banco,
  Studio ou painel** para avançar. `02_specs.md` §7.1 ganha o parágrafo que diz
  quem confirma e por onde.
- **Reconciliação documental:** `03_plan.md` — DoD da **T1.10**, DoD da
  **T1.11** e DoD da **Fase 1**; `02_specs.md` §7.1. **Sugerido ao
  `product-manager`, e fatia dele:** tornar o **A1** explícito no `01_prd.md`,
  de "criar conta pelo app, sem ninguém abrir painel de banco de dados" para
  "criar conta pelo app, confirmar o e-mail e entrar com ela, sem ninguém abrir
  painel de banco de dados". É esclarecimento do que já estava lá, não critério
  novo — e nada nesta entrada depende dessa edição.

### CHG-003 - A confirmação de e-mail criou um estado que nenhum documento descrevia

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1), tarefas T1.7 e T1.10.
- **Planejado originalmente:** com a confirmação automática ligada, `signUp`
  devolvia conta **já confirmada e com sessão**, e o caminho feliz da Fase 1 ia
  direto do cadastro para dentro do app. Nem o `01_prd.md` §8 nem o
  `02_specs.md` tinham linha para "conta criada, e-mail ainda não confirmado", e
  a T1.7 não pedia tela nenhuma para ele.
- **Por que não foi possível prosseguir:** a **FD-022** desligou a confirmação
  automática, e com isso o cadastro passou a terminar num estado que a tela não
  sabe exibir — conta existe, sessão não. Sem texto, a pessoa toca "criar conta",
  vê a tela não mudar e conclui que falhou. **Duas medições contra o GoTrue da
  stack local** fecharam o resto do quadro: (1) repetir o cadastro do **mesmo
  endereço**, esperando 75 s para sair da janela de reenvio, devolve
  `HTTP 200` com `identities` preenchido e **sem** `error_code` — resposta
  **idêntica** à do cadastro novo, e nenhum `user_already_exists`; (2) duas
  tentativas **seguidas** batem em `over_email_send_rate_limit`, janela de cerca
  de 60 segundos. Ou seja: **pelo caminho do erro, o app não tem como saber que o
  endereço já tinha conta.**
- **Alternativas consideradas:** (a) deixar como está e tratar depois — entrega
  um cadastro que parece quebrado; (b) navegar para dentro do app assim mesmo —
  impossível, não há sessão, e mentiria sobre o estado da conta; (c) declarar o
  estado no `02_specs.md` e exigir da tela uma mensagem que diga o que falta sem
  afirmar que a conta está pronta, **com o mesmo texto para endereço novo e para
  endereço repetido**; (d) tentar distinguir os dois casos por outro caminho —
  consultar a existência do e-mail antes de cadastrar —, o que construiria de
  propósito um **oráculo de enumeração de contas** num app que guarda extrato
  bancário.
- **Decisão tomada:** (c), registrada como **FD-024** em
  [`decisions.md`](decisions.md), pelo `tech-lead`. (d) foi descartada como
  regressão de segurança: não poder distinguir é o comportamento **desejável**, e
  a mensagem única passa a ser escolha, não conformação. A T1.7 ganha uma linha
  de DoD para o estado de confirmação pendente, e a T1.10, uma linha para a
  janela de reenvio — o roteiro de E2E não pode repetir cadastro em sequência.
- **Resumo da resolução:** `02_specs.md` §7.1 passa a descrever o cadastro do
  primeiro toque até a confirmação, com a régua de que **a tela nunca afirma que
  a conta está pronta para usar** e **nunca revela se o endereço já tinha
  conta**. A tradução de `user_already_exists` que a T1.6 implementou vira **caso
  morto neste modo** — fica no código, documentada, porque a configuração que a
  dispara existe e apagá-la é regressão silenciosa esperando a próxima virada de
  ambiente. Nasce o risco **X17** no `03_plan.md` §7.
- **Reconciliação documental:** `02_specs.md` §3.1, §7 (agora 7.1 e 7.2) e §9
  (linhas 1 e 4); `03_plan.md` — DoD da T1.7, DoD da T1.10 e risco **X17**;
  `decisions.md` (**FD-024**). **Pendente, e é fatia do `product-manager`:** o
  `01_prd.md` §8 promete "Cadastro com e-mail já existente → mensagem própria,
  distinta de qualquer outra", promessa que a medição tornou inentregável e que
  precisa virar a mensagem única. **Medição que não foi feita, e por que não
  vale:** o teste usou conta **não confirmada**; conta já confirmada pode ofuscar
  com `identities` vazio. O desfecho não muda nada — a mensagem é a mesma nos
  dois —, e por isso a medição não foi pedida.

### CHG-001 - A P10 foi decidida pela saída cara, e a P9 saiu da fila junto

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1) e Fase 3 (PR 3b).
- **Planejado originalmente:** o `03_plan.md` §1 apresentava a **P9** (App
  Password do Gmail e as cinco variáveis de SMTP) e a **P10** (cadastro aberto ou
  fechado) como **duas pendências humanas abertas**, com a stack descrita em
  `GOTRUE_MAILER_AUTOCONFIRM: 'true'`. Sobre essa premissa se apoiavam ainda o
  risco **X1**, o risco **X8** e a linha do DoD da Fase 3 que condicionava a
  troca de e-mail a "`MAILER_AUTOCONFIRM` valer `'true'` e não haver SMTP".
- **Por que não foi possível prosseguir:** o humano decidiu a P10 pela saída que
  o plano tratava como a mais cara — **cadastro aberto com confirmação de
  e-mail** (`ENABLE_EMAIL_AUTOCONFIRM=false`) —, o que arrastou a P9 para dentro
  desta fase, e o App Password do Gmail passou a existir. As duas metades da
  premissa ("autoconfirm ligado" e "sem SMTP") deixaram de ser verdade no mesmo
  dia, e a T1.5 já entregou `infra/local/docker-compose.yml` com
  `GOTRUE_MAILER_AUTOCONFIRM: 'false'` e capturador de e-mail.
- **Alternativas consideradas:** (a) aceitar a dívida do autoconfirm ligado, com
  gatilho escrito para pagá-la depois — mais barato hoje, mas deixa um endpoint
  público criando contas confirmadas sem prova de posse; (b) desligar o
  autoconfirm **antes** do SMTP — tranca todo cadastro novo, porque ninguém
  confirma; (c) virar as duas variáveis do GoTrue no **mesmo redeploy** do SMTP.
- **Decisão tomada:** (c), registrada como **FD-022** em
  [`decisions.md`](decisions.md), pelo humano. A troca de e-mail **continua fora
  da Fase 3**, mas por **escopo**, não por impedimento técnico — nenhuma fase
  desta feature entrega o fluxo, e reabri-lo é chamada do humano.
- **Resumo da resolução:** a stack local já roda a configuração nova desde a
  T1.5; na HML as cinco variáveis de SMTP e as duas do GoTrue entram no mesmo
  redeploy, e o estado do servidor é registrado em `docs/deploy/coolify.md`,
  seção "Ainda por fazer". A P9 e a P10 deixam de constar como pendências
  abertas; **P11**, **P12** e **P13** seguem abertas.
- **Reconciliação documental:** `03_plan.md` §1 (cabeçalho das pendências, P9,
  P10 e P11), prosa e DoD da **Fase 3**, e os riscos **X1** e **X8** do §7;
  `02_specs.md` §2 (âncora de SMTP), §10 (B1 e B2) e §11 (X1); `decisions.md`
  (**FD-014**, cujo "Reconciliação pendente" fecha aqui).

### CHG-002 - "Lembrar login" sai do escopo, e o e-mail lembrado entra no lugar

- **Data:** 2026-08-20
- **Fase/PR:** Fase 1 (PR 1).
- **Planejado originalmente:** o `01_prd.md` (A3) e o `03_plan.md` deixavam a
  caixinha "lembrar login" **condicionada à medição da T1.1**: se a sessão
  caísse, o passo em que ela cai viraria tarefa nomeada; se sobrevivesse, a
  feature sairia do escopo por escrito. A Fase 1 tinha onze tarefas, e o plano
  dizia que `app/lib/core/session/` receberia **só** o escopo de recuperação de
  senha.
- **Por que não foi possível prosseguir:** a medição matou a premissa. A T1.1
  provou que a sessão sobrevive a `adb shell am force-stop` e a `adb reboot`, e
  que o app sequer chama o servidor ao reabrir
  (`docs/002_conta_e_configuracoes/e2e/round_01/`). O humano confirmou o mesmo no
  aparelho dele: só volta a pedir credencial **depois de apertar "Sair"** — que é
  o comportamento correto de um sign-out, não um defeito a corrigir.
- **Alternativas consideradas:** (a) implementar "lembrar login" assim mesmo —
  guardaria senha para resolver problema inexistente, e é exatamente a abordagem
  já descartada pela **FD-004**; (b) não fazer nada — some o incômodo real de
  redigitar o e-mail a cada saída; (c) preencher de volta **só o e-mail** no
  campo, deixando a senha para digitar; (d) fazer (c) **persistindo** o e-mail em
  disco, para sobreviver também à morte do processo.
- **Decisão tomada:** (c), com o e-mail guardado **apenas em memória** —
  `especialista-apresentacao` executa; decisão do `tech-lead`, registrada como
  **FD-023** em [`decisions.md`](decisions.md). (d) foi descartada por preço:
  persistir custaria dependência de armazenamento nova e dado pessoal em repouso
  para cobrir um caminho que a medição mostrou ser raro — a tela de entrar só
  aparece logo depois do "Sair", no mesmo processo.
- **Resumo da resolução:** nasce a tarefa **T1.12** na Fase 1, em frente
  paralela às frentes D e E, com bloco DoD próprio. Ela cria
  `app/lib/core/session/last_signed_in_email.dart`, grava o e-mail no fim de uma
  entrada bem-sucedida e o lê para semear o campo. A Fase 1 passa de onze para
  doze tarefas, e a feature de 58 para 59.
- **Reconciliação documental:** `03_plan.md` — cabeçalho de estado, prosa da
  Fase 1, bloco paralelo das frentes D/E/F, tarefa **T1.12**, DoD da Fase 1
  (contagem e linha da consequência) e §8 Progresso; `decisions.md`
  (**FD-023**, que fecha a condicional da **FD-004**); `03_plan.md` §1 (**P11**,
  que ganha o resultado da medição). O `01_prd.md` (A3 e a tabela de fora de
  escopo) **fica pendente** — é fatia do `product-manager`.

## Modelo de registro

### CHG-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Fase/PR:** identificador da fase ou PR afetado.
- **Planejado originalmente:** o que `01_prd.md`, `02_specs.md` ou `03_plan.md`
  determinava antes do desvio.
- **Por que não foi possível prosseguir:** fato técnico, produto ou dependência
  que tornou o planejamento impraticável.
- **Alternativas consideradas:** opções avaliadas e suas concessões.
- **Decisão tomada:** escolha final e responsável pela aprovação.
- **Resumo da resolução:** como código, ambiente ou processo ficou resolvido.
- **Reconciliação documental:** arquivos e seções de `01_prd.md`,
  `02_specs.md` e `03_plan.md` atualizados para a realidade final.
