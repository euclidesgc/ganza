---
name: instrumentar-e2e
description: Prepara o E2E de uma feature do ganza automatizando o máximo num script idempotente e auto-limpante, com prints gerados pela máquina em emulador Android. Usada pelo QA após o gate do CISO. Nada aqui vai para produção.
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

## 1. Script de contrato — `scripts/e2e-local.sh NNN`

Use `scripts/local-supabase.sh` para subir a stack e `scripts/e2e-local.sh NNN` para validar o **máximo por API/CLI**, com `PASS/FAIL` explícito. O roteiro específico fica em `docs/NNN_<nome>/`.

- **Determinístico e idempotente.** Roda N vezes seguidas sem limpeza manual. Use **base efêmera**: `docker compose down -v` + `up` → o schema nasce das migrations, do zero. **Nunca** rode ação destrutiva contra o banco de produção; nunca aponte o script para o Supabase remoto.
- **Cobre o contrato inteiro** que a feature toca: cada verbo/rota do backend, os campos de resposta, os invariantes, os erros do PRD e os casos de borda. Uma asserção por invariante.
- **Cobre as invariantes que só o banco prova:**
  - a **RLS realmente barra**: consulta com o token de outro usuário (ou anônimo) devolve vazio/403 — não basta a política existir no SQL;
  - nada foi gravado sem confirmação: após a ingestão, a tabela final está vazia e só `proposed_actions` tem linha;
  - o cálculo financeiro bate com o valor esperado, ao centavo.
- **Auto-limpante e rastreável.** Todo rastro (processos, containers, volumes, arquivos) é listado e removido por um subcomando `down`, e escrito no cabeçalho do script e no `test_plan.md`.
- **Zero mudança de código-fonte** quando a stack real está pronta. Rode você mesmo e só entregue **verde**.

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
- Cada `round_MM/` recebe um `report.md` emitido pelo script, com **cada imagem descrita**: passo, comando, resultado e o que aquele estado prova. É assim que o dev confere — abre o relatório e olha.

**O que só o olho pega**, e por isso vai para o print e não para a asserção: hierarquia visual, contraste real da paleta, alvo de toque confortável na mão, e o principal — se a tela **parece** que está celebrando alguma coisa. Sem confete é regra de produto e se verifica olhando.

## 3. Notificação exige um roteiro próprio

É o risco R3 do plano e o modo de falha mais caro: alarme exato restrito no Android 12+ e fabricante matando background. O roteiro **precisa** provar, com o **app fechado** (`adb shell am force-stop <pkg>`):

1. push de servidor chega (a via confiável: `pg_cron` → backend → FCM);
2. alarme local dispara ou falha **de forma visível**, nunca silenciosa;
3. o app abre no lugar certo ao tocar na notificação.

Testar com o app aberto não prova nada e é o erro clássico aqui.

## 4. Instrumentação de código — só se inevitável

Se a stack real **não** está pronta, aí sim instrumente: fakes no DI do flavor dev (honrando o contrato de verdade — erros e bordas, não só a interface) e `log()` (`dart:developer`) nos pontos que contam a história. **Prefixo `[e2e]` em tudo** e a lista completa (arquivos + trechos) no `test_plan.md` — é o mapa da limpeza no wrap. Prefira sempre o script à instrumentação.

## 5. Rodadas e evidências

```
docs/NNN_<nome>/e2e/round_01/   ← 1ª rodada
docs/NNN_<nome>/e2e/round_02/   ← 2ª rodada (após correções)
```

Em cada `round_MM/`: o **snapshot dos scripts**, os **prints** e o **`report.md`** descrevendo cada imagem. O ciclo:

1. O QA roda `scripts/e2e-local.sh NNN`, que chama `patrol test`; sem
   `RODADA`, o executor reserva a primeira pasta disponível entre `01` e `03`
   e recusa sobrescrever evidência. O dev **confere** as imagens e os logs.
   Vídeos não são gerados.
2. **Tudo passou** → wrap (limpeza + testes automatizados + DoD). Fim das rodadas.
3. **Achou problema** → o time analisa logs, prints e código, corrige o que for código e **ajusta o script** se preciso. Só então avisa que a `rodada_MM+1` está pronta.

## Regras de ouro

- **Máquina valida contrato; humano valida percepção.** Passo manual que pode virar asserção, vira.
- **Uma rodada = uma pasta.** Nunca sobrescreva evidência anterior — o histórico das rodadas é o rastro do que quebrou.
- **Nunca rode E2E contra o banco de produção.** Ele guarda o extrato bancário real de uma pessoa.
- Todo o rastro fica listado no `test_plan.md` — é o mapa da limpeza no wrap.
