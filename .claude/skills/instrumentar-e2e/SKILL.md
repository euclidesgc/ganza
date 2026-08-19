---
name: instrumentar-e2e
description: Prepara o E2E de uma feature do ganza automatizando o máximo num script idempotente e auto-limpante, com prints gerados pela máquina em emulador Android. Usada pelo QA após o gate do CISO, em tarefas separadas de instrumentar e de executar, cada uma com o seu bloco DoD. Nada aqui vai para produção.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__dart__list_devices, mcp__dart__launch_app, mcp__dart__stop_app, mcp__dart__get_app_logs
---

# Skill: instrumentar o E2E

Objetivo: validar de ponta a ponta o que fizemos, **minimizando o passo manual** — quanto mais clique manual, mais chance de o dev testar errado e mascarar bug. A regra: **automatize tudo que a máquina consegue verificar; deixe ao humano só o que exige olho.** Esta fase não gera PR — tudo aqui é temporário.

**O alvo primário é Android.** O executor canônico é `patrol test`, sobre
`patrolTest`, em um emulador. Ele mantém as asserções Dart e acrescenta
automação de UI nativa; MCP é apenas ferramenta de exploração, nunca gate.
Versione a ponte JUnit parametrizada em `android/app/src/androidTest/.../
MainActivityTest.java`: ela chama `PatrolJUnitRunner.listDartTests()` e
`runDartTest()`; sem ela um APK pode terminar com zero testes executados.

## 0. Instrumentar não é executar — são duas tarefas

**Instrumentar** é escrever o driver, o script e a captura dos prints: trabalho de
código, raciocínio denso, muita chamada de ferramenta, contexto grande.
**Executar** é rodar contra o emulador e a stack e colher a evidência: espera de
parede, pouco raciocínio, muito tempo morto. São naturezas diferentes e por isso
**vão em tarefas separadas, cada uma com o seu bloco DoD** — o bloco é o pacote
"o que fazer + como se prova", e é ele que o `supervisor-dod`
(`.claude/agents/supervisor-dod.md`) julga ao fim de cada tarefa. Despachar as
duas juntas é o que transforma o E2E no maior executor da sessão.

**Mas o limite é real e está escrito de propósito:** quem escreveu o driver é
quem melhor o depura quando a rodada sai vermelha. A única decisão aqui é se as
duas tarefas vão para o **mesmo** agente — retomando-o, que custa de 3 a 5× menos
que abrir um novo, porque o contexto já está carregado — ou para dois agentes.
Qualquer das duas serve; **registre a escolha com a razão** no `03_plan.md`, junto
da tarefa. Não invente cerimônia de paralelismo onde a dependência é real: aqui
ela é.

## 1. Script de contrato — `scripts/e2e-local.sh NNN`

Use `scripts/local-supabase.sh` para subir a stack e `scripts/e2e-local.sh NNN` para validar o **máximo por API/CLI**, com `PASS/FAIL` explícito. O roteiro específico fica em `docs/NNN_<nome>/`.

- **Determinístico e idempotente.** Roda N vezes seguidas sem limpeza manual. Use **base efêmera**: `docker compose down -v` + `up` → o schema nasce das migrations, do zero. **Nunca** rode ação destrutiva contra o banco de produção; nunca aponte o script para o Supabase remoto.
- **Cobre o contrato inteiro** que a feature toca: cada verbo/rota do backend, os campos de resposta, os invariantes, os erros do PRD e os casos de borda. Uma asserção por invariante.
- **Cobre as invariantes que só o banco prova:**
  - a **RLS realmente barra**: consulta com o token de outro usuário (ou anônimo) devolve vazio/403 — não basta a política existir no SQL;
  - nada foi gravado sem confirmação: após a ingestão, a tabela final está vazia e só `proposed_actions` tem linha;
  - o cálculo financeiro bate com o valor esperado, ao centavo.
- **Auto-limpante e rastreável.** Todo rastro (processos, containers, volumes, arquivos) é listado e removido por um subcomando `down`, e escrito no cabeçalho do script e na seção `## Rastro` do `report.md` da rodada.
- **Zero mudança de código-fonte** quando a stack real está pronta. E o script não se entrega sem ter rodado: **verde é a entrega da tarefa de execução**, e o humano nunca recebe roteiro que ninguém rodou.
- **Sentinela de término é do script, não de quem espera.** A primeira linha executável instala `trap 'printf "EXIT=%s\n" "$?"' EXIT`, para que o marcador saia também quando o script morre por erro, `set -e` ou sinal. Sentinela colado por fora (`bash script; echo EXIT=$?`) some junto com o wrapper e deixa todo waiter esperando para sempre um processo que já morreu — deadlock silencioso, o modo de falha mais caro deste harness porque parece execução em andamento.
- **O log diz em que ponto está.** Cada cena abre com uma linha marcada e prefixo de tempo decorrido, para que uma olhada no `tail` responda "onde está e há quanto tempo" sem ler o arquivo inteiro.
- **Cena lenta é declarada.** Passo que degrada a rede de propósito (`adb emu network delay gprs`), reinstala o APK ou espera timeout anuncia no log o custo esperado — sem isso, lentidão projetada é indistinguível de travamento.

## 2. Prints do app — `docs/NNN_<nome>/e2e_shots.sh` (o QA gera, o humano confere)

Regra: **o QA gera TODOS os prints; o dev humano só confere** — nunca opera o app à mão.

- **Android (primário):** `patrol` + `patrol_cli`, contra emulador headless
  (`emulator -no-window -no-audio`). O teste solicita o print no ponto exato
  ao servidor local de captura, que usa
  `adb screencap` e salva PNG em `e2e/round_MM/`. Nenhum passo visual é
  aprovado sem PNG correspondente. Configure `adb reverse` e use
  `127.0.0.1` no callback: o loopback continua acessível quando o cenário
  bloqueia o Supabase local. Para provar falha de rede, rejeite apenas o host
  da stack local por `iptables`; não desligue Wi-Fi/dados e não aceite diálogos
  do sistema como evidência.
- **Web (quando a fase tem alvo web):** Patrol Web ou Playwright, com prints e
  resultados em pasta de rodada. Não reutilize o executor Android para simular
  navegador.
- **Widget que precisa de `Key` para ser dirigido ganha `Key` no código de produção** — `Key` não é instrumentação, é API de teste; ela fica.
- Cada `round_MM/` recebe um `report.md` de **duas origens**: o script emite o
  esqueleto, e **quem instrumentou completa** o que script nenhum tem como saber.
  Os rótulos são literais — `scripts/verify-gauntlet.sh` os cobra por `grep`:
  - **do script:** o título `# Round MM …`, `## Contexto`, `## Passos executados`
    (a tabela que liga cada passo ao comando, ao resultado e ao PNG que o prova,
    dizendo **o que aquele estado prova**) e `## Ambiente e comandos`. O guard
    exige ao menos um PNG referenciado, e todo arquivo referenciado tem de
    existir na pasta da rodada.
  - **de quem instrumentou:** `## Rastro` — processos, containers, volumes e
    arquivos que o subcomando `down` remove — e `## Limpeza no wrap`, a lista
    completa de arquivos e trechos com prefixo `[e2e]` (uma linha dizendo que
    não houve instrumentação de código, quando for o caso).

  **Todo link do relatório resolve dentro da própria pasta da rodada**: sem `/`
  inicial e sem `..`, ou o guard reprova. Caminho de arquivo do repositório vai
  em crase, nunca como link — como link ele vira evidência ausente. É assim que
  o dev confere — abre o relatório e olha.

**O que só o olho pega**, e por isso vai para o print e não para a asserção: hierarquia visual, contraste real da paleta, alvo de toque confortável na mão, e o principal — se a tela **parece** que está celebrando alguma coisa. Sem confete é regra de produto e se verifica olhando.

## 3. Notificação exige um roteiro próprio

É o risco R3 do plano e o modo de falha mais caro: alarme exato restrito no Android 12+ e fabricante matando background. O roteiro **precisa** provar, com o **app fechado** (`adb shell am force-stop <pkg>`):

1. push de servidor chega (a via confiável: `pg_cron` → backend → FCM);
2. alarme local dispara ou falha **de forma visível**, nunca silenciosa;
3. o app abre no lugar certo ao tocar na notificação.

Testar com o app aberto não prova nada e é o erro clássico aqui.

## 4. Instrumentação de código — só se inevitável

Se a stack real **não** está pronta, aí sim instrumente: fakes no DI do flavor dev (honrando o contrato de verdade — erros e bordas, não só a interface) e `log()` (`dart:developer`) nos pontos que contam a história. **Prefixo `[e2e]` em tudo** e a lista completa (arquivos + trechos) na seção `## Limpeza no wrap` do `report.md` da rodada, escrita à mão por quem instrumentou. Prefira sempre o script à instrumentação.

## 5. Rodadas e evidências

```
docs/NNN_<nome>/e2e/round_01/   ← 1ª rodada
docs/NNN_<nome>/e2e/round_02/   ← 2ª rodada (após correções)
```

Em cada `round_MM/`: o **snapshot dos scripts**, os **prints** e o **`report.md`** completo — esqueleto do script mais `## Rastro` e `## Limpeza no wrap`. O ciclo:

1. O QA roda `scripts/e2e-local.sh NNN`, que chama `patrol test`; sem
   `RODADA`, o executor reserva a primeira pasta disponível entre `01` e `03`
   e recusa sobrescrever evidência. O dev **confere** as imagens e os logs.
   Vídeos não são gerados.
2. **Tudo passou** → wrap (limpeza + testes automatizados + DoD). Fim das rodadas.
3. **Achou problema** → **volta para quem instrumentou.** Quem escreveu o driver
   é quem o depura, e retomar esse agente custa de 3 a 5× menos que explicar o
   roteiro a um novo. Ele analisa logs, prints e código, corrige o que for código
   e **ajusta o script** se preciso. A `round_MM+1` é então uma tarefa de execução
   nova, com bloco DoD próprio.

## Regras de ouro

- **Máquina valida contrato; humano valida percepção.** Passo manual que pode virar asserção, vira.
- **Uma rodada = uma pasta.** Nunca sobrescreva evidência anterior — o histórico das rodadas é o rastro do que quebrou.
- **Nunca rode E2E contra o banco de produção.** Ele guarda o extrato bancário real de uma pessoa.
- **O relatório não sai inteiro de script.** `## Rastro` e `## Limpeza no wrap` são escritos por quem instrumentou; sem eles o wrap não sabe o que remover.
