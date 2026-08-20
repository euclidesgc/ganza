# Histórico de mudanças - Feature 002 - Conta, configurações e chaves do usuário

Este arquivo é append-only. Registre uma entrada antes de mudar a implementação
ou os documentos canônicos por causa de um desvio descoberto após o início da
feature. Depois da entrada, reconcilie PRD, specs e plano para que descrevam o
estado final, sem preservar neles uma versão obsoleta do planejamento.

## Mudanças registradas

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
