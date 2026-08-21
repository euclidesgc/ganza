# Histórico de mudanças - Feature 002 - Conta, configurações e chaves do usuário

Este arquivo é append-only. Registre uma entrada antes de mudar a implementação
ou os documentos canônicos por causa de um desvio descoberto após o início da
feature. Depois da entrada, reconcilie PRD, specs e plano para que descrevam o
estado final, sem preservar neles uma versão obsoleta do planejamento.

## Mudanças registradas

### CHG-020 - A premissa da chave-mestra do Vault era inferência, e a medição a inverteu

- **Data:** 2026-08-21
- **Fase/PR:** Fase 4 (PR 4b), depois da onda 1. Alcança a pendência **P12**, os
  riscos **X5** e **X16** do plano, o **X4** e o bloqueio **B4** das specs, e a
  linha do DoD da Fase 4 que citava a consequência.
- **Planejado originalmente:** o plano afirmava que a chave-mestra do `pgsodium`
  — com a qual o `supabase_vault` cifra todo segredo — vivia em
  `/etc/postgresql-custom/pgsodium_root.key` **na camada gravável do contêiner**,
  também em produção, e que recriar o Postgres tornaria todo segredo do Vault
  ciphertext permanentemente indecifrável. Daí saíam três coisas: a pendência
  humana **P12** ("montar a chave em volume muda estado de serviço da VPS
  compartilhada e depende de autorização do humano"), os riscos **X5** e **X16**,
  e uma linha no **DoD da Fase 4** exigindo que `decisions.md` registrasse a
  consequência **"nenhuma chave real de IA é salva em produção enquanto a P12 não
  fechar"**. O `01_prd.md` repetia a mesma consequência como restrição de produto,
  e o `02_specs.md` a repetia como bloqueio **B4** e risco **X4**.
- **Por que não foi possível prosseguir:** a premissa **nunca foi medida**. Ela
  saiu da leitura de `infra/local/docker-compose.yml`, que monta só
  `db-data:/var/lib/postgresql/data`, mais a suposição não verificada de que "a
  stack de produção nasceu do mesmo desenho". A **T4.3** foi ao servidor em
  21/08/2026, com comandos **só de leitura**, e mediu o contrário: a chave está
  dentro do volume nomeado `lqsjrqqs6r8rnggbvwpi4nuf_supabase-db-config`, montado
  em `/etc/postgresql-custom`, e **recriar o contêiner `supabase-db` não a
  destrói**. Executor e supervisor conferiram de forma independente, cada um na
  VPS. As saídas de `ls -l` e de `docker inspect` estão coladas em
  `docs/deploy/coolify.md`, seção "Chave-mestra do Vault (`pgsodium`) — recriar
  `supabase-db` não a destrói"; a decisão está em
  [`decisions.md`](decisions.md), **FD-032**. Com isso, três documentos passaram a
  afirmar por escrito um fato falso, e uma pendência humana passou a pedir
  autorização para um trabalho já feito.
- **Alternativas consideradas:** (a) **manter a restrição "nenhuma chave real em
  produção" por precaução**, trocando de justificativa — recusada: restrição sem
  motivo escrito é superstição operacional, e a próxima pessoa a lê como se
  ainda houvesse um risco medido por trás; se nenhum motivo a sustenta, ela sai,
  e o que fica no lugar são as **condições que a reabrem**, nomeadas; (b)
  **converter a P12 em outra pendência humana**, agora sobre "não remover o
  volume" — recusada: isso já está coberto pela regra geral de não executar ação
  destrutiva na VPS compartilhada sem ordem do humano, e restrição permanente de
  operação não é pendência aberta, é regra; (c) **riscar X5 e X16 e seguir** —
  recusada: apagaria a procedência, e a procedência é o que impede a mesma
  inferência de ser refeita; (d) **reescrever X5/X16/P12 preservando o que se
  supunha, o que foi medido e quando, fechar a P12 e transformar o resíduo real
  numa tarefa** — escolhida.
- **Decisão tomada:** (d), pelo `tech-lead`, com o fato medido registrado como
  **FD-032** pela T4.3. A **P12 fecha em 21/08/2026 por medição, não por
  autorização** — não sobrou pedido ao humano, porque o volume que faltaria já
  existe e a única mudança restante é no repositório. A restrição **"nenhuma
  chave real de IA é salva em produção" deixa de valer** e sai do DoD da Fase 4:
  conferiu-se motivo por motivo e nenhum outro a sustenta — a fase seguir se
  provando contra a stack local é sequência de trabalho, não proibição; e a
  ausência de backup (**D4**) não a segura, porque o pior caso de perder o volume
  é cada pessoa salvar a chave de novo, já que chave de IA se reobtém no
  provedor, ao contrário de dado financeiro.
- **Resumo da resolução:** **X5 muda de sujeito, não some** — deixa de ser "a
  chave-mestra não está em volume" e passa a ser "**a stack local diverge da de
  produção**", que é o que sobrou de verdadeiro: em
  `infra/local/docker-compose.yml` o modo de falha existe de fato, e enquanto os
  dois desenhos divergirem a próxima medição feita ali volta a ser lida como
  verdade sobre produção. **X16 registra a queda do bloqueio** e guarda as **duas
  condições que o reabrem**, ambas não testadas porque testá-las mudaria estado
  de serviço compartilhado: remover o volume
  `lqsjrqqs6r8rnggbvwpi4nuf_supabase-db-config` (`docker compose down -v` ou
  `docker volume rm`) e um redeploy do Coolify que recrie a stack sem preservá-lo.
  Se qualquer uma ocorrer, os segredos existentes param de abrir e a tela de IA
  cai no estado de falha do cubit da **T4.10**, com o caminho de volta sendo
  salvar a chave outra vez. **O remendo agora é o inverso do que o plano previa**
  — nada a aplicar em produção, e sim replicar
  `supabase-db-config:/etc/postgresql-custom` na stack local: virou a tarefa
  **T4.15**, mudança só no repositório, sem tocar a VPS e sem autorização a pedir.
  Ela fica na **onda 5** porque **T4.2** e **T4.14** provam contra a stack local e
  mexer no compose durante essas provas as invalidaria — a restrição é a stack
  compartilhada, não o arquivo. **Esta entrada não implementa a T4.15.**
  **O bloco de DoD da T4.3 fica como está**, com o veredito `CUMPRIDO`
  preservado: as suas linhas são condicionais ("enquanto a chave não estiver em
  volume…", "se a chave não estiver em volume…") e continuam verdadeiras como
  condicionais; reescrever bloco já julgado seria reescrever o registro.
- **Reconciliação documental:**
  - `docs/002_conta_e_configuracoes/03_plan.md` — §1: **P12** reescrita e
    **fechada**, com o que se supunha, o que foi medido e quando; a linha "duas
    delas já caíram" vira "três". §5, Fase 4: nasce a tarefa **T4.15** com bloco
    DoD, a tabela de **Ondas de execução** ganha a T4.15 na onda 5 marcada
    `[paralela]`, a linha do DoD da fase que citava a consequência antiga é
    reescrita para o que a **FD-032** de fato registra, e a contagem da fase vai
    de **12 para 13** tarefas (na linha do DoD, na §8 e no total da feature, que
    vai de 64 para 65). §7: a prosa de abertura e as células **X5** e **X16**
    reescritas.
  - `docs/002_conta_e_configuracoes/02_specs.md` — §10: **B4** marcada resolvida
    por medição. §11: **X4** reescrito como divergência entre stacks.
  - `docs/002_conta_e_configuracoes/01_prd.md` — §11: o item da chave-mestra
    reescrito, com a restrição de produto removida e a procedência preservada.
    **Arquivo de fatia do `product-manager`, editado aqui por pedido explícito do
    orquestrador** por conter afirmação factual que ficou falsa.
  - `docs/002_conta_e_configuracoes/decisions.md` — a **FD-018** ("nenhuma chave
    real de IA é salva em produção enquanto a chave-mestra do cofre não estiver em
    volume") estava viva na tabela de decisões vigentes afirmando a premissa
    invertida, e nenhum documento a marcava: fica **riscada e revogada pela
    FD-032**, preservada em vez de removida porque o plano e esta entrada a citam
    como a premissa que caiu. A **FD-032**, escrita pela T4.3, não é alterada.
  - `docs/deploy/coolify.md` — a seção da chave-mestra, escrita pela T4.3, não é
    alterada por esta entrada; ela é a fonte da medição. A frase dela que anuncia
    o remendo local como pendente sai quando a **T4.15** for executada, e isso é
    linha do DoD da T4.15.

### CHG-019 - O E2E sai de escopo, e o lote de fechamento perde a razão de existir

- **Data:** 2026-08-20
- **Fase/PR:** Fase 3 (PR 3b), no fechamento. Alcança as Fases 4, 5 e 6, ainda
  não iniciadas, e o lote de fechamento (§9 do plano).
- **Planejado originalmente:** a **D30** de `docs/decisions.md`, de 20/08/2026,
  tirou as rodadas **novas** de E2E do caminho crítico de cada fase e as mandou
  para um **lote de fechamento** (§9), com dono, arquivos e o bloco DoD já
  escrito. As rodadas `round_03` a `round_06` continuariam existindo — apenas
  depois da última fase de implementação —, e a §9 era gate: enquanto uma linha
  dela estivesse aberta, a feature 002 não seria dada por entregue.
- **Por que não foi possível prosseguir:** decisão do humano em 20/08/2026,
  **E2E suspenso por completo — o projeto trabalha apenas com testes unitários e
  de widget.** Isso sobrepõe a D30 na parte do lote: o que era **pendência
  adiada** vira **escopo removido**. Manter a §9 como estava deixaria quinze
  linhas de DoD que ninguém vai executar bloqueando a entrega da feature, e um
  gate que ninguém roda deixa de ser gate e vira opinião.
- **Alternativas consideradas:** (a) manter as rodadas na §9 marcadas como
  opcionais — é o pior dos dois mundos: continuam pesando na leitura do plano e
  não pesam mais no gate; (b) apagar a §9 em bloco — rápido, e perde toda
  exigência cuja **única** prova era a rodada, em silêncio, que é exatamente o
  modo de falha que a **D32** já pagou; (c) aplicar linha a linha a régua já
  usada na T2.4 e na T5.6 — print redundante sai **seco**, com uma linha de
  justificativa; exigência cuja prova única era a rodada **migra para teste de
  widget** ou saída de comando; e o que não couber em nenhum dos dois é dito por
  extenso como buraco aceito, nunca omitido.
- **Decisão tomada:** (c), pelo `tech-lead`, com a decisão do humano registrada
  como **D34** em `docs/decisions.md`. Saem do plano as nove tarefas de E2E —
  **T1.16**, **T2.6**, **T2.7**, **T3.9**, **T3.10**, **T4.12**, **T4.13**,
  **T5.7** e **T5.8** — e as onze linhas de print que a §9 guardava. A §9 é
  reformulada: deixa de ser "o lote de rodadas adiadas" e passa a ser o lote das
  exigências que perderam a prova, com quatro tarefas novas de dono declarado —
  **TL.1** (abandono da recuperação), **TL.2** (cadeia do drawer até
  transações), **TL.3** (troca de senha logado não desloga nem navega) e
  **TL.4** (remoção física de `app/patrol_test/`, da dependência `patrol` em
  `app/pubspec.yaml` e das menções restantes). **`app/patrol_test/` deixa de ser
  mantido a partir de agora; a remoção é a TL.4 e não é deste PR** — enquanto o
  diretório existir, ele ainda precisa formatar e analisar limpo, porque o
  `.github/workflows/ci.yml` roda `dart format` e `flutter analyze` sobre a
  pasta `app/` inteira.
- **Resumo da resolução:** duas exigências ficam **sem prova automatizada**, e
  estão escritas assim na §9: o **glifo do Remix Icon desenhado** (o print da
  T2.1; sobra a conferência de codepoint contra o `remixicon.glyph.json` da tag
  `v4.9.1`, que prova que o codepoint existe na fonte, não que ele desenha) e a
  **integração real com a sandbox da Pluggy** (a T5.3 cobre o contrato da Edge
  Function com o `fetch` stubado, não a sandbox no ar). Um efeito colateral
  achado ao reconciliar: a **T4.14** escrevia a prova de isolamento em
  `docs/002_conta_e_configuracoes/e2e/round_05/isolamento.md`, e o
  `scripts/verify-gauntlet.sh` exige um `report.md` válido em **todo** diretório
  sob `e2e/` — sem a T4.13 para gerá-lo, o guard passaria a falhar por um
  diretório órfão. A prova mudou de endereço para
  `docs/002_conta_e_configuracoes/provas/isolamento_credenciais_ia.md`, fora de
  `e2e/`, que é onde ela sempre pertenceu: é `curl` e `psql`, nunca foi rodada
  de emulador. `docs/002_conta_e_configuracoes/e2e/round_01/` e `round_02/`
  continuam no repositório como registro histórico. Contagem da feature: **69 →
  64** (menos nove tarefas de E2E, mais quatro do lote). Junto, e pelo mesmo
  toque: toda linha de DoD das Fases 4, 5 e 6 passou a usar
  `dart format --output=none --set-exit-if-changed`, porque sem `--output=none`
  o comando **escreve** o arquivo ao medir — prova que muta a árvore que ela
  deveria medir (achado do `supervisor-dod` em 20/08/2026).
- **Reconciliação documental:** `docs/002_conta_e_configuracoes/03_plan.md`
  (seção Gauntlet, Fase 3, Fase 4, Fase 5, Fase 6, §6, §7 nos riscos **X3** e
  **X19**, §8 e §9), `docs/decisions.md` (**D30** revisada, **D34** e **D35**
  novas) e `CHANGELOG.md`. O `01_prd.md` e o `02_specs.md` não descrevem
  política de teste e não foram tocados.

### CHG-018 - O DoD da T3.12 não pedia formato, e formatar cegava o gate que a tarefa criou

- **Data:** 2026-08-20
- **Fase/PR:** Fase 3 (PR 3b), no fechamento, com a T3.12 já marcada CUMPRIDO.
- **Planejado originalmente:** o bloco DoD da **T3.12** cobrava que o guard
  passasse a acusar rota nomeada nunca navegada, que o repositório atual saísse
  `0`, que houvesse escape documentado, que a checagem **mordesse** e que
  `bash -n scripts/gates_guard.sh` saísse `0`. Cinco linhas, todas sobre o
  **script**.
- **Por que não foi possível prosseguir:** a tarefa também mexe em **arquivo
  Dart** — o escape mora na declaração da rota — e nenhuma linha exigia
  `dart format`. O executor pôs o escape como comentário de fim de linha e os
  dois gates viraram **mutuamente exclusivos**: sem formatar, o CI reprova;
  formatando, o `dart format` quebra a declaração em duas linhas e o regex do
  guard deixa de enxergá-la — cego exatamente na rota para a qual o escape foi
  escrito.
- **Alternativas consideradas:** (a) só mandar consertar o detector, tratando
  como descuido do executor — deixa o critério errado de pé para a próxima tarefa
  de gate; (b) acrescentar a linha de formato ao bloco **e** registrar a regra
  geral, porque a tarefa tem **duas superfícies** (o script e o código que ele
  varre) e o DoD só cobria uma.
- **Decisão tomada:** (b), pelo `tech-lead`. O bloco da T3.12 ganha uma sexta
  linha que exige `cd app && dart format --set-exit-if-changed lib` em `0`
  **antes** das provas de mordida e de escape, com as saídas coladas nessa ordem
  — provar no estado em que o executor deixou o arquivo não prova nada sobre o
  CI. A regra geral virou a **D33** de `docs/decisions.md`, com a parte que
  importa: **o escape se prende à declaração, não à linha física**, e detector
  que casa só numa das formas é defeituoso.
- **Resumo da resolução:** nenhuma tarefa nasceu; a feature segue com **69**. A
  varredura dos outros blocos de gate achou **a mesma lacuna na T2.9** — o gate
  do `Icons.` cru, já fechado —, cujo bloco também não pede `dart format` e cuja
  prova de mordida edita um arquivo Dart sem formatá-lo. Ali o risco é menor
  porque `Icons.add` não se quebra em duas linhas, **mas o escape `// gate4-ok` é
  por linha física e tem a mesma fragilidade**: fica como dívida escrita na D33,
  barata de conferir enquanto alguém tiver o script aberto. **Pergunta do
  orquestrador respondida e registrada na D33:** fazer o guard falhar sobre
  código fora de formato **não** teria pego este caso, porque no CI o repositório
  está sempre formatado e era ali que o gate estava cego — ideia recusada com a
  razão escrita, para não voltar.
- **Reconciliação documental:** `docs/decisions.md` (**D33**) e
  `docs/002_conta_e_configuracoes/03_plan.md` (sexta linha do bloco da T3.12).
  `01_prd.md`, `02_specs.md` e `decisions.md` desta pasta não mudam.

### CHG-017 - A troca de senha estava pronta e inalcançável, e é a terceira vez que a soma não entrega o fluxo

- **Data:** 2026-08-20
- **Fase/PR:** Fase 3 (PR 3b), achado pelo executor da T3.8.
- **Planejado originalmente:** a **T3.7** faria a tela de troca de senha e a
  **T3.8** registraria a rota `/configuracoes/conta/senha` fora do `ShellRoute`,
  mais o DI. As duas cumpriram o que prometiam, com DoD aprovado.
- **Por que não foi possível prosseguir:** **nenhum widget aciona a rota.** A tela
  de Conta não tem link para trocar a senha, e a funcionalidade ficou navegável
  por nome e inalcançável por quem usa o app. Nenhum DoD pegou porque o link não
  era dito por nenhuma das duas tarefas — a T3.8 cobra a entrada de **Conta** na
  home de Configurações, não a de senha dentro da tela de Conta.
- **Alternativas consideradas:** (a) tratar como esquecimento e mandar consertar
  sem registrar — deixa a classe do problema viva; (b) só acrescentar linha ao
  DoD da Fase 3 — alguém teria de executá-la de todo modo, e linha de fase sem
  tarefa dona é exatamente o defeito da **T2.4**; (c) criar a tarefa do link
  **e** atacar a classe, com rede mecânica e rede por fase.
- **Decisão tomada:** (c), pelo `tech-lead`. Nasce a **T3.11**
  (`especialista-apresentacao`, no PR 3b): controle **"Trocar senha"** na tela de
  Conta, navegando pela rota nomeada, provado por **teste de cadeia** em
  `app/test/app_router_test.dart` que parte de `/`, abre o menu e toca até
  `/configuracoes/conta/senha` — mais a reversão. Nasce a **T3.12**
  (`especialista-infra`, no PR 3b, paralela à T3.11 porque só toca
  `scripts/gates_guard.sh`): o guard passa a acusar rota nomeada declarada e
  nunca navegada, com escape para rota alcançada só por `redirect`. **A classe do
  problema virou a D32** de `docs/decisions.md`, com as duas redes e a condição
  que a T2.4 ensinou: linha de DoD de fase precisa nomear em qual bloco de tarefa
  a prova é escrita.
- **Resumo da resolução:** a Fase 3 vai de 10 para **12** tarefas e leva **9** ao
  PR 3b; a feature, de 67 para **69**. As Fases 4 e 5 ganharam a linha de
  alcançabilidade **com dono**: a da Fase 4 é escrita pela **T4.11** (uma linha
  nova no bloco) e a da Fase 5 pela **T5.6** (linha existente estendida, para o
  bloco não passar de seis). A Fase 6 fica isenta por não entregar tela. **Se o
  PR 3b ficar grande, a T3.12 é a que se move de fase sem perder nada** — ela
  protege o futuro, não esta entrega.
- **Reconciliação documental:** `docs/decisions.md` (**D32**);
  `docs/002_conta_e_configuracoes/03_plan.md` — tarefas **T3.11** e **T3.12** com
  bloco DoD, nota de dependência, linha de alcançabilidade no DoD das Fases 3, 4
  e 5, linha nova no bloco da T4.11, linha estendida no da T5.6, contagem do DoD
  da Fase 3, §8 Progresso e cabeçalho. `01_prd.md` e `02_specs.md` não mudam: o
  fluxo prometido sempre foi este, o que faltava era o widget que o alcança.

### CHG-016 - O DoD da Fase 3 mandava a migration para o PR errado, e o número de tarefas quase foi corrigido para o lado errado

- **Data:** 2026-08-20
- **Fase/PR:** Fase 3 (PR 3a em execução), antes de o PR 3b existir.
- **Planejado originalmente:** o cabeçalho da Fase 3 estabelece **dois PRs** para
  que a migration vá antes e sozinha — PR 3a com `feature/GZ-26-nome-no-perfil`,
  PR 3b com a fase —, mas a primeira linha do DoD da fase dizia "as oito tarefas
  que a fase leva ao **PR 3b** — T3.1 a T3.8". A **T3.1 é a migration**. Do jeito
  escrito, ou o PR 3a não tinha conteúdo, ou a T3.1 entrava nos dois.
- **Por que não foi possível prosseguir:** a Fase 3 começou. Com a redação
  antiga, quem abrisse o PR 3b levaria a migration junto e desfaria a regra do
  `docs/GITFLOW.md` que a fase cita duas linhas acima.
- **Alternativas consideradas:** (a) corrigir a lista **e** baixar o número de
  oito para sete, já que o PR 3b leva sete tarefas — **é a correção errada**, e
  quase foi feita: o grep conta `- [x] **T3.N** … DoD: CUMPRIDO` na **fase
  inteira**, e no momento em que a linha é verificada — fechamento do PR 3b — a
  T3.1 já mergeou e já está marcada, então o grep devolve oito. Sete faria o gate
  falhar por aritmética, não por trabalho faltando; (b) corrigir só a lista e a
  divisão de PR, mantendo o número, e **escrever na própria linha por que ele não
  encolhe**.
- **Decisão tomada:** (b), pelo `tech-lead`. A linha da Fase 3 passa a dizer que a
  **T3.1 vai sozinha no PR 3a** e **T3.2 a T3.8 no PR 3b**, mantém `8` e explica
  que a contagem é da fase e não do PR. **O mesmo tratamento preventivo foi
  aplicado às Fases 4 e 5**, que têm a mesma estrutura: lá a redação não estava
  errada — dizia "aos PRs 4a e 4b", no plural —, mas era **ambígua**, porque não
  nomeava quais tarefas iam em cada PR. Agora nomeia: **T4.1 e T4.2** (as duas
  migrations) no PR 4a e **T4.3 a T4.11 mais a T4.14** no PR 4b; **T5.1** no PR 5a
  e **T5.2 a T5.6** no PR 5b. Os números `12` e `6` também ficam, pela mesma
  razão, agora escrita.
- **Resumo da resolução:** nenhuma tarefa nasceu, morreu ou mudou de fase — a
  feature segue com **67**. O que mudou foi a redação que mandava trabalho para o
  PR errado e o risco de "consertar" a contagem para um número que reprovaria o
  gate. Aproveitado o mesmo commit, o estado do plano foi posto em dia: **Fases 1
  e 2 mergeadas** (PRs **#26** e **#27**, mais o **#28** de harness), `develop` em
  `bc684da`, Fase 3 em andamento, e o §8 Progresso passa a dizer quantas tarefas
  cada PR leva em vez de só o total.
- **Reconciliação documental:** `docs/002_conta_e_configuracoes/03_plan.md` —
  primeira linha do DoD das Fases 3, 4 e 5, cabeçalho de estado e §8 Progresso.
  `01_prd.md`, `02_specs.md`, `decisions.md` e `docs/decisions.md` não mudam:
  nenhuma decisão foi tomada aqui, só redação corrigida.

### CHG-015 - O risco X2 estava mitigado por um mecanismo que não existe

- **Data:** 2026-08-20
- **Fase/PR:** Fase 2 (PR 2), no `fechar-etapa`, antes de o PR abrir.
- **Planejado originalmente:** o risco **X2** — o `DrawerButton` que o `Scaffold`
  injeta reintroduz o glifo do Material — era dado por tratado com esta frase, no
  plano e no `02_specs.md`: `scripts/gates_guard.sh` "procura o literal `Icons.`",
  e o botão injetado não escreve esse literal, logo bastava a linha de DoD com
  `grep -rn 'Icons\.' app/lib` vazio.
- **Por que não foi possível prosseguir:** as duas metades da frase são falsas.
  **A primeira:** `rtk proxy grep -n 'Icons' scripts/gates_guard.sh` não devolve
  nada — o script não tem checagem de ícone nenhuma; o Gate 4 dele cobre
  `Color(0x`, `Colors.<nome>`, `fontSize`, `circular(` e `EdgeInsets`, e mais
  nada. **A segunda:** o padrão `'Icons\.'` sem âncora casa como substring de
  `AppIcons.`, então o critério "não devolve nenhuma linha" é incumprível — hoje
  devolve **13**, todas legítimas. O risco estava mitigado no papel por mecanismo
  inexistente, e a prova que sobrava era inexequível. Resíduo do mesmo padrão
  ainda estava em quatro pontos (`03_plan.md` na nota da Fase 2 e na linha do X2;
  `02_specs.md` na armadilha do guard e na tabela de riscos).
- **Alternativas consideradas:** (a) reescrever só o texto do risco, dizendo que
  o que protege é a linha de DoD com o grep ancorado — honesto e barato, mas a
  proteção morre no fim da Fase 2, porque nenhuma feature seguinte repete essa
  linha; (b) **pôr a checagem no guard**, que é onde ela vale para sempre e roda
  em todo PR, e corrigir o texto do risco junto.
- **Decisão tomada:** (b), pelo `tech-lead`. O argumento que decide é o
  **precedente do `Colors.<nome>`**: o guard já recusa a constante crua do
  Material quando ela substitui um token de cor, e ícone virou responsabilidade
  de `core/theme/` pela **D22**. Recusar `Icons.` cru é a mesma regra, e a
  ausência dela é omissão, não escolha de desenho. Nasce a **T2.9**
  (`especialista-infra`, camada infra, no PR 2), com bloco DoD de cinco linhas:
  a checagem entra ancorada, o repositório atual continua saindo `0`, e a prova
  de que **morde** é introduzir um `Icons.add` cru, ver saída diferente de `0` e
  restaurar — mais o escape `// gate4-ok` continuando a valer.
- **Resumo da resolução:** o texto do X2 passa a dizer o que de fato protege, em
  duas camadas — a linha de DoD **hoje**, o guard **a partir da T2.9** — e os
  quatro resíduos do padrão cru foram trocados pelo ancorado
  `(^|[^A-Za-z])Icons\.`, com a razão da âncora escrita em cada um, para ninguém
  "simplificar" de volta. Fase 2 vai de 8 para **9** tarefas e leva **7** ao PR 2;
  a feature, de 66 para **67**. **Varredura dos outros riscos, rodando cada
  mecanismo citado:** X3 (`app/patrol_test/` existe e está fora de `test/`), X5
  (`infra/local/docker-compose.yml` monta só `db-data:/var/lib/postgresql/data`,
  sem a chave-mestra do Vault), X7 (`envVars` em
  `supabase/functions/main/index.ts:42`), X10 (`scripts/local-supabase.sh:130`
  com o `to_regclass('public.transactions')`), X17 (**FD-024** em `decisions.md`)
  e X18 (`app/lib/core/session/password_recovery_scope.dart`) — **todos
  verdadeiros**. O X2 era o único falso.
- **Reconciliação documental:** `docs/002_conta_e_configuracoes/03_plan.md`
  (linha do X2, nota da Fase 2, tarefa **T2.9**, contagem do DoD da fase, §8 e
  cabeçalho), `docs/002_conta_e_configuracoes/02_specs.md` (armadilha do guard e
  tabela de riscos) e `docs/decisions.md` (**D31** ganha o fato medido).
  `scripts/gates_guard.sh` **não** foi tocado: mexer nele é a T2.9.

### CHG-014 - O contrato de navegação não cede a um teste mal montado, e a T2.5 deixa uma tarefa para trás

- **Data:** 2026-08-20
- **Fase/PR:** Fase 2 (PR 2), durante a execução da **T2.5**.
- **Planejado originalmente:** a tabela de rotas da §3 do plano fixa
  `/configuracoes` **dentro** do `ShellRoute` e todas as sub-rotas
  (`/configuracoes/conta`, `/configuracoes/conta/senha`, `/configuracoes/ia`,
  `/configuracoes/banco`) **fora** dele. A razão está no desenho e não é
  cosmética: `/configuracoes` é um **destino de topo**, listado no drawer, e o
  shell é justamente o que carrega o drawer. As sub-rotas ficam fora para cada
  uma manter `AppBar` própria com seta de voltar — é o que a **T3.8** já cobra.
- **Por que não foi possível prosseguir:** o executor aninhou
  `SettingsRoutes.route` no shell com `parentNavigatorKey` nas sub-rotas, como o
  contrato pede, e
  `app/test/modules/settings_module/presentation/settings_home_page_test.dart`
  quebrou: o teste monta um `GoRouter` **próprio e isolado, sem a chave de
  navegador root**, e o go_router lança assert quando uma rota referencia uma
  chave que aquele router não conhece. Ele reverteu e deixou `/configuracoes`
  como rota de topo, fora do shell — com o efeito de a tela de Configurações
  ganhar seta de voltar e **perder o drawer**.
- **Alternativas consideradas:** (a) **o contrato cede** — aceitar Configurações
  fora do shell, mais barato e sem tarefa nova, ao preço de a pessoa não alcançar
  o drawer de dentro das Configurações e ter de voltar antes de trocar de área;
  (b) **o teste é que estava mal montado** — corrigir o teste para exercitar o
  router do app em vez de um router de mentira, e devolver `/configuracoes` ao
  shell.
- **Decisão tomada:** (b), pelo `tech-lead`. **O contrato não cede.** Um teste de
  widget que monta um `GoRouter` isolado não conhece a topologia do app e não
  pode ditá-la — a cauda não balança o cachorro. E a alternativa (a) contraria a
  promessa 3 da §6 do plano, "navegação de topo por drawer": um item de drawer
  que leva a uma tela **sem** drawer é exatamente o que essa promessa nega. O
  defeito é do harness do teste, não do router. **Nasce a T2.8**
  (`especialista-infra`, camada infra/presentation, no PR 2): devolver
  `/configuracoes` ao `ShellRoute` e reescrever o teste para exercitar o router
  do app, com bloco DoD próprio de cinco linhas — incluindo a reversão, que tirar
  a rota do shell faz o teste falhar.
- **Resumo da resolução:** nada do contrato mudou; o que mudou foi o
  reconhecimento de que a prova estava errada. A Fase 2 passa de 7 para **8**
  tarefas e leva **6** ao PR 2 (T2.1 a T2.5 e T2.8; T2.6 e T2.7 seguem no lote de
  fechamento), e a feature vai de 65 para **66**. O estado atual do código —
  `/configuracoes` fora do shell — é **desvio conhecido e temporário**, fechado
  pela T2.8 antes do PR 2. Regra que fica: quando um teste impede a topologia
  correta, o conserto é no teste; "conserte o router, não o teste" vale para
  regressão de comportamento, não para harness que não sabe montar o alvo.
- **Reconciliação documental:** `docs/002_conta_e_configuracoes/03_plan.md` —
  tarefa **T2.8** com bloco DoD e a nota que a explica, contagem do DoD da Fase 2,
  §8 Progresso e o cabeçalho. A tabela de rotas da §3 **não muda**: ela já dizia o
  certo. `01_prd.md`, `02_specs.md` e `decisions.md` desta pasta não mudam.

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
- **Segunda leva, mesma decisão e mesma autoria (20/08/2026):** a varredura
  inicial não alcançou três blocos da Fase 2, e um deles escondia lacuna maior.
  **T2.1** perde o print `00_tokens_de_icone.png`, e a linha vizinha passa a dizer
  que a conferência de codepoint contra o `remixicon.glyph.json` da tag `v4.9.1` é
  a **prova única** de que o glifo existe — antes ela dividia o papel com o print.
  **T2.3** tinha duas linhas que citavam o print `01_drawer_aberto.png` **junto**
  da conferência por leitura: partidas como a 1246, a leitura fica e o print
  migra. **T2.4** era o caso grave e **não é de política**: o parágrafo "O que
  esta fase não cobra mais" afirmava que a troca de navegação seguia provada
  "pelo teste de widget da T2.4", e o bloco da T2.4 **não pedia teste nenhum** — a
  home era provada só pelo print. O parágrafo prometia prova inexistente. O print
  sai e entram **duas linhas**: teste de widget em
  `app/test/modules/settings_module/presentation/settings_home_page_test.dart`
  provando as três seções com rótulo textual e a navegação sem lançar, e a linha
  de reversão, que remover uma seção faz o teste falhar; a linha de
  format/analyze passa a cobrir `test/modules/settings_module`. **Não é acréscimo
  de exigência: é a prova que o DoD da fase já afirmava existir, escrita onde se
  cumpre.** As três entram na §9 com caminho completo, sob a mesma nota — decisão
  do orquestrador, não do humano, reversível pela §9.
- **Terceira leva — a régua do print aplicada às seis restantes, com o critério
  que a T5.6 revelou:** antes de remover, perguntar se o print é **prova única**
  de alguma exigência ou **redundante** com uma linha vizinha que fica.
  Redundante sai seco — foi o caso da **T4.7**, onde a conferência por leitura de
  `app/lib/core/widgets/forms/secret_field.dart` já sustentava a exigência
  sozinha. Prova única **não sai sem substituto**, sob pena de apagar exigência
  em vez de adiar prova: **T3.6**, **T3.7**, **T3.8**, **T4.10** e **T5.6**
  ganharam teste de widget com caminho completo, o que ele assere, o comando que
  o roda e a **linha de reversão** — sem ela o teste prova que passa, não que
  mede. Nenhum bloco passou de seis linhas. Os prints continuam listados na §9,
  porque a rodada ainda os colhe; o que mudou é que a exigência deixou de
  depender deles. Mesma autoria: decisão do orquestrador, reversível pela §9.
- **Quarta leva — prova vazia, achada pelo `supervisor-dod` ao julgar a T2.2:**
  `scripts/gates_guard.sh` isenta `app/lib/core/theme/` por caminho, então a
  linha do DoD da **T2.2** que mandava rodar o guard e esperar `0` passava **por
  construção** — o guard não olha o escopo daquela tarefa. A linha perdeu a
  citação ao guard e ganhou o aviso de não a reintroduzir; a exigência que ela
  fingia cobrir virou **grep pareado** na linha do `ListTileThemeData`, positivo
  (`AppSpacing.touchTarget` presente) mais negativo (nenhum número cru nas
  propriedades de altura). Na varredura do defeito inverso apareceram mais duas:
  a contagem da **T2.1**, que com arquivo vazio imprimiria `0` nos dois `grep -c`
  e passaria, agora exige o número ser **pelo menos onze**; e a linha do DoD da
  **Fase 4** sobre `aiConfigured`, cujo "devolve só arquivos sob" era satisfeito
  por saída vazia, agora exige **os três** caminhos presentes e nenhum outro. O
  fato ficou na **D31** de `docs/decisions.md`, não aqui, porque vale para toda
  feature futura. `scripts/gates_guard.sh` **não** foi tocado.
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
