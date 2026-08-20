# Histórico de mudanças - Feature 002 - Conta, configurações e chaves do usuário

Este arquivo é append-only. Registre uma entrada antes de mudar a implementação
ou os documentos canônicos por causa de um desvio descoberto após o início da
feature. Depois da entrada, reconcilie PRD, specs e plano para que descrevam o
estado final, sem preservar neles uma versão obsoleta do planejamento.

## Mudanças registradas

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
