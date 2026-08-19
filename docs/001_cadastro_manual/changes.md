# Histórico de mudanças - Feature 001 - Cadastro manual

Este arquivo é append-only. Desvios descobertos após o início da implementação
entram aqui antes da alteração de código, PRD, specs, plano ou DoD. Os três
documentos canônicos descrevem somente o estado final reconciliado.

## Mudanças registradas

### CHG-008 - Evidência da rodada 01 precede o harness Patrol local

- **Data:** 2026-08-18
- **Fase/PR:** Fase 3, PR #19 (mergeado), reconciliação de status da Fase 4.
- **Planejado originalmente:** o Gauntlet deste plano e a T3.8 exigem que o
  E2E rode **somente contra a stack local, por `patrol test`**, com a ponte
  JUnit versionada e captura por `adb reverse`.
- **Por que não foi possível prosseguir:** a rodada 01 foi executada e mergeada
  **antes** de CHG-002 a CHG-007, contra o ambiente remoto e pelo executor
  `flutter drive`. O próprio `e2e/round_01/report.md` declara a rodada
  histórica e diz que ela "não pode ser usada como prova para um novo PR". O
  plano reconciliado passou a descrever um contrato que a Fase 3 nunca chegou
  a cumprir na forma atual.
- **Alternativas consideradas:** reexecutar a rodada 01 sob Patrol na stack
  local; reabrir a Fase 3 e desfazer o merge do PR #19; ou aceitar a rodada 01
  como registro histórico e cobrar a prova visual da listagem dentro da rodada
  02, que já exercita a mesma tela sob o harness canônico. Reexecutar a 01
  custa uma rodada inteira para reprovar o que a 02 prova de qualquer jeito;
  desfazer o merge não devolve nenhuma informação nova.
- **Decisão tomada:** manter a Fase 3 mergeada e a rodada 01 como evidência
  histórica; a prova visual da listagem sob Patrol/stack local é obrigação da
  rodada 02 — `app/patrol_test/registro_transacao_test.dart` já assere a linha
  nova no topo da lista, a descrição, a data e o valor formatado. Aprovado pelo
  tech-lead; nenhuma linha de DoD, rubrica ou invariante foi alterada.
- **Resumo da resolução:** `e2e/round_01/` continua versionado e rotulado como
  rodada histórica; o `report.md` da rodada 02 passa a ser a única evidência
  citável para a listagem e para o registro.
- **Reconciliação documental:** `03_plan.md` §8 (Fase 3 marcada como mergeada
  pelo PR #19, com a ressalva apontando para este registro) e este `changes.md`.
  `01_prd.md` e `02_specs.md` não mudam: o contrato de E2E já é o de Patrol
  local e permanece exigível da rodada 02 em diante.

### CHG-007 - E2E reduzido a Patrol com PNG e ownership do emulador

- **Data:** 2026-08-18
- **Fase/PR:** harness E2E local da feature 001.
- **Planejado originalmente:** manter alvos em `integration_test/` e gravar
  vídeo bruto por cenário.
- **Por que não foi possível prosseguir:** a convenção confundia o executor
  Patrol com o pacote Flutter `integration_test`, e vídeos elevavam custo de
  armazenamento sem acrescentar prova ao PNG marcado pela asserção.
- **Alternativas consideradas:** vídeo obrigatório, vídeo sob demanda ou PNG
  obrigatório sem vídeo. Também foi avaliado matar todo emulador encontrado.
- **Decisão tomada:** alvos em `patrol_test/`, somente PNG+logs por padrão e
  controlador com arquivo de ownership que encerra apenas o emulador iniciado
  pelo harness.
- **Resumo da resolução:** unitários, widgets e Patrol são as três camadas de
  teste; os roteiros recusam concorrência e não deixam AVD próprio órfão.
- **Reconciliação documental:** `01_prd.md`, `02_specs.md`, `03_plan.md`,
  `decisions.md`, `pubspec.yaml`, roteiros E2E e a skill passam a descrever
  Patrol, PNG/logs e ownership explícito.

### CHG-001 - Stand-in de `auth.uid()` alinhado ao formato real do GoTrue

- **Data:** 2026-08-18
- **Fase/PR:** Fase 1, PR de migration `transactions`.
- **Planejado originalmente:** a prova de RLS usaria o stand-in de
  `auth.uid()` já presente em `supabase/ci-bootstrap.sql`.
- **Por que não foi possível prosseguir:** o stand-in lia
  `request.jwt.claim.sub`, mas o GoTrue expõe `request.jwt.claims` como JSON.
  Com `auth.uid()` nulo, a RLS negaria também o dono e poderia produzir uma
  falsa prova de isolamento.
- **Alternativas consideradas:** alterar apenas o texto do DoD, manter o
  stand-in com fallback escalar, ou corrigir a função para o formato real.
- **Decisão tomada:** corrigir `auth.uid()` para ler
  `request.jwt.claims ->> 'sub'`, preservando uma prova de RLS representativa.
- **Resumo da resolução:** o bootstrap de CI e a prova local montam as claims
  JSON do GoTrue; inserção do dono e negação anônima deixam de se confundir.
- **Reconciliação documental:** `01_prd.md` §7, `02_specs.md` §3 e
  `03_plan.md` Fase 1/DoD passam a exigir a sessão no formato real.

### CHG-002 - Executor E2E migrado de `flutter drive` para Patrol

- **Data:** 2026-08-18
- **Fase/PR:** harness E2E local da feature 001.
- **Planejado originalmente:** os cenários de emulador eram executados por
  `integration_test` com `flutter drive`, driver hospedeiro e comandos `adb`
  auxiliares para preparar e capturar evidências.
- **Por que não foi possível prosseguir:** esse executor exige instrumentação
  específica para screenshots e não controla adequadamente UI nativa; permissões,
  teclado, ciclo de app e diálogos do sistema aumentariam a fragilidade do
  harness conforme as features avançarem.
- **Alternativas consideradas:** manter `flutter drive`; adicionar Marionette
  MCP para navegação por agente; ou migrar os cenários determinísticos para
  Patrol com seu CLI. Marionette foi descartado como gate porque exploração por
  agente não substitui prova reprodutível em CI.
- **Decisão tomada:** usar `patrol` e `patrol_cli` como executor de E2E Android,
  preservando a stack Supabase local, as asserções Dart e o relatório por rodada.
- **Resumo da resolução:** os roteiros passam a chamar `patrol test`; testes
  adotam `patrolTest` e mantêm screenshots, logs e códigos de saída como
  evidência. `flutter_driver` e o driver hospedeiro são removidos.
- **Reconciliação documental:** `01_prd.md` §7, `02_specs.md` E2E,
  `03_plan.md` Gauntlet/Fases 3 e 4, `CLAUDE.md` e a skill
  `instrumentar-e2e` passam a descrever Patrol como executor canônico.

### CHG-003 - Ponte Android nativa explicitada para o Patrol

- **Data:** 2026-08-18
- **Fase/PR:** harness E2E local da feature 001.
- **Planejado originalmente:** a configuração do `PatrolJUnitRunner` e o
  comando `patrol test` seriam suficientes para descobrir os cenários Dart.
- **Por que não foi possível prosseguir:** o APK instrumentado executou com
  sucesso, porém o relatório Android declarou zero testes. O runner precisa de
  uma classe JUnit parametrizada em `androidTest` para listar e executar cada
  `patrolTest` presente no bundle Dart.
- **Alternativas consideradas:** voltar ao `flutter drive`; criar uma ponte
  temporária em cada roteiro; ou versionar uma ponte Android mínima e estável.
  O driver não resolve a integração nativa, e gerar código a cada rodada
  dificulta auditoria e reprodução.
- **Decisão tomada:** versionar `MainActivityTest.java` em `androidTest`,
  baseado no contrato do Patrol, usando `PatrolJUnitRunner` para listar e
  executar os testes Dart.
- **Resumo da resolução:** a instrumentação Android passa a ter um ponto de
  entrada explícito, revisável e reutilizável por todos os cenários da feature.
- **Reconciliação documental:** `01_prd.md` §7, `02_specs.md` E2E,
  `03_plan.md` T3.8/T4.7 e a skill `instrumentar-e2e` exigem a ponte nativa.

### CHG-004 - Captura offline usa loopback revertido por ADB

- **Data:** 2026-08-18
- **Fase/PR:** harness E2E local da feature 001.
- **Planejado originalmente:** a rodada offline extrairia o último frame do
  vídeo do Patrol porque o callback HTTP de captura usa a rede do emulador.
- **Por que não foi possível prosseguir:** depois de finalizar o teste, o
  último frame pode conter um diálogo do launcher, não o estado que a asserção
  validou. Essa imagem seria uma evidência visual inválida.
- **Alternativas consideradas:** escolher um instante fixo do vídeo; manter
  apenas vídeo; ou encaminhar `127.0.0.1` do emulador ao servidor de captura
  do host por `adb reverse`. Instantes de vídeo continuam frágeis e vídeo não
  substitui o print no passo marcado.
- **Decisão tomada:** usar `adb reverse tcp:8765 tcp:8765` e o callback
  `http://127.0.0.1:8765` em todos os cenários, inclusive sem Wi-Fi/dados.
- **Resumo da resolução:** o teste pede o screenshot no estado exato; o
  servidor local executa `adb screencap`, enquanto Patrol ainda grava o vídeo
  bruto como evidência complementar.
- **Reconciliação documental:** `02_specs.md` E2E, `03_plan.md` T3.8/T4.7 e
  a skill `instrumentar-e2e` passam a exigir `adb reverse` para a captura.

### CHG-005 - Captura ocorre sem espera adicional após a asserção visual

- **Data:** 2026-08-18
- **Fase/PR:** harness E2E local da feature 001.
- **Planejado originalmente:** o helper de evidência aguardaria 300 ms depois
  da asserção antes de solicitar o screenshot.
- **Por que não foi possível prosseguir:** o desligamento de Wi-Fi/dados no
  emulador headless pode abrir um ANR do System UI nesse intervalo e ocultar a
  tela já validada pelo teste.
- **Alternativas consideradas:** aumentar a espera, capturar um frame do vídeo
  ou capturar imediatamente após a asserção que estabiliza a UI. Esperar piora
  a interferência e vídeo não identifica o ponto exato.
- **Decisão tomada:** o helper solicita a captura imediatamente após a
  asserção; cada cenário já aguarda o estado esperado antes de chamá-lo.
- **Resumo da resolução:** o PNG prova a tela validada, sem janela temporal
  extra para diálogos externos ao aplicativo.
- **Reconciliação documental:** `02_specs.md` E2E e `03_plan.md` T3.8/T4.7
  definem o print no marcador posterior à asserção, sem atraso artificial.

### CHG-006 - Falha de rede é isolada no tráfego do Supabase local

- **Data:** 2026-08-18
- **Fase/PR:** harness E2E local da feature 001.
- **Planejado originalmente:** o roteiro desabilitaria Wi-Fi e dados do
  emulador com `svc` para induzir falha de rede.
- **Por que não foi possível prosseguir:** no emulador headless Android 35,
  essa operação pode abrir um ANR do System UI antes do screenshot e ocultar a
  tela do aplicativo, invalidando a prova visual.
- **Alternativas consideradas:** ignorar o diálogo, usar modo avião ou bloquear
  apenas o destino do Supabase local. Diálogo e modo avião preservam a mesma
  interferência de sistema; o bloqueio de destino preserva o comportamento que
  a feature precisa tratar.
- **Decisão tomada:** inserir regra `iptables` para rejeitar saída ao host
  `10.0.2.2`, onde a app acessa o Supabase local, e removê-la no `trap`.
- **Resumo da resolução:** a app recebe erro real de transporte; o emulador,
  o loopback de captura e a evidência visual permanecem livres de diálogos do
  sistema.
- **Reconciliação documental:** `01_prd.md` §7, `02_specs.md` E2E,
  `03_plan.md` T3.8/T4.7 e `instrumentar-e2e` definem indisponibilidade do
  Supabase local, não desligamento global do emulador.

## Modelo de registro

### CHG-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Fase/PR:** identificador da fase ou PR afetado.
- **Planejado originalmente:** o que PRD, specs ou plano determinava antes do
  desvio.
- **Por que não foi possível prosseguir:** fato técnico, produto ou dependência
  que tornou o planejamento impraticável.
- **Alternativas consideradas:** opções avaliadas e suas concessões.
- **Decisão tomada:** escolha final e responsável pela aprovação.
- **Resumo da resolução:** como código, ambiente ou processo ficou resolvido.
- **Reconciliação documental:** arquivos e seções de PRD, specs e plano
  atualizados para a realidade final.
