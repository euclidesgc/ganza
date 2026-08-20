# Round 01 — medição da persistência da sessão no aparelho (T1.1)

## Contexto

Esta rodada **mede**, não implementa. A pergunta da T1.1 é se a sessão do
`supabase_flutter` sobrevive a encerrar o app e a reiniciar o aparelho, e — se
não sobreviver — em que passo exato ela cai.

Alvo: **emulador**, não aparelho físico. Nenhum aparelho estava conectado
(`adb devices` voltava vazio), então a medição rodou no AVD **`Pixel_8_Pro`**
(Android 15, serial `emulator-5554`), iniciado sem janela pelo próprio harness
do repositório. O `userdata` do AVD é um disco persistente e sobrevive ao
`adb reboot`, que reinicia o sistema convidado sem derrubar o processo do
emulador — foi assim que o caso "reiniciar o aparelho" foi exercido.

Backend: **stack local descartável**, subida por `scripts/local-supabase.sh up`.
Nada de HML e nada de produção. A conta usada é a que o próprio script cria
(`e2e@ganza.local`), com a credencial definida dentro de
`scripts/local-supabase.sh`; ela nasce com quatro áreas padrão, o que faz a tela
inicial ter conteúdo verificável a olho.

O app é o APK do flavor **dev** (`applicationId br.com.ganza.ganza.dev`),
compilado em **debug** de propósito: só um build depurável responde a
`adb shell run-as`, exigido para inspecionar as preferências.

Commit da árvore no momento da rodada: `0a2e1de`.

## Passos executados

| # | Passo | Comando | Evidência |
| --- | --- | --- | --- |
| 1 | App instalado e aberto pela primeira vez; pede e-mail e senha | `adb -s emulator-5554 install -r -t app/build/app/outputs/flutter-apk/app-dev-debug.apk` e `adb -s emulator-5554 shell am start -W -n br.com.ganza.ganza.dev/br.com.ganza.ganza.MainActivity` | [00a_login_inicial.png](00a_login_inicial.png) |
| 2 | Entrada com a conta local; app vai para a lista de áreas | `adb -s emulator-5554 shell input tap 675 1642` (botão "Entrar", depois de `input text` nos dois campos) | [00b_areas_apos_login.png](00b_areas_apos_login.png) |
| 3 | App encerrado e reaberto: **continua logado** | `adb -s emulator-5554 shell am force-stop br.com.ganza.ganza.dev` seguido de `adb -s emulator-5554 shell am start -W -n br.com.ganza.ganza.dev/br.com.ganza.ganza.MainActivity` | [01_sessao_apos_restart.png](01_sessao_apos_restart.png) |
| 4 | Aparelho reiniciado e app reaberto: **continua logado** | `adb -s emulator-5554 reboot`, `adb -s emulator-5554 wait-for-device`, espera por `getprop sys.boot_completed = 1` e novo `am start` | [02_sessao_apos_reboot.png](02_sessao_apos_reboot.png) |
| 5 | Sonda extra: validade local da sessão adulterada para o passado e app reaberto | edição do campo `expires_at` dentro do arquivo de preferências por `adb -s emulator-5554 shell "run-as br.com.ganza.ganza.dev sh -c 'cat > /data/data/br.com.ganza.ganza.dev/shared_prefs/FlutterSharedPreferences.xml'"` e novo `am start` | [03_sessao_apos_expiracao_forcada.png](03_sessao_apos_expiracao_forcada.png) |

A tabela lista só os passos com asserção visual. O levantamento de onde a sessão
foi gravada em disco, feito entre os passos 2 e 3, tem saída de texto e está
descrito abaixo.

**Onde a sessão mora.** Rodando
`adb -s emulator-5554 shell run-as br.com.ganza.ganza.dev ls /data/data/br.com.ganza.ganza.dev/shared_prefs/`
com o app já logado, o único arquivo em
`/data/data/br.com.ganza.ganza.dev/shared_prefs/` é
**`FlutterSharedPreferences.xml`**, e a chave que guarda a sessão é
**`flutter.sb-10-auth-token`** — o prefixo `flutter.` é do plugin
`shared_preferences`, e o resto é a chave `sb-<host>-auth-token` que o
`supabase_flutter` monta a partir do host configurado (`10.0.2.2`). O valor é um
JSON de 2821 bytes com o token de acesso, o de renovação, o tipo, a validade e o
usuário. **Nenhum valor foi copiado para esta pasta**: as evidências registram
nome de arquivo, nome de chave e tamanho, nada mais — ver
[logs/shared_prefs.txt](logs/shared_prefs.txt).

**O que o servidor viu.** O GoTrue local só recebeu requisição de entrada uma
vez, no passo 2 (`POST /token`, `200`, às 19:03:44Z; a de 19:02:37Z é a
verificação da credencial feita do host por `curl`, antes de usar o app). Nas
reaberturas dos passos 3, 4 e 5 **nenhuma requisição chegou ao GoTrue** — o app
restaurou a sessão do disco sem falar com o servidor. Ver
[logs/gotrue_requisicoes.txt](logs/gotrue_requisicoes.txt).

**Ressalva sobre o passo 5.** É sonda complementar, não é caso do DoD, e o
resultado é fraco de propósito: adulterar o `expires_at` gravado localmente não
adultera o `exp` do token em si, então o app pôde continuar válido sem renovar.
Ela não prova que a renovação por token de validade vencida funciona — prova
apenas que a sessão não é descartada ao ser lida com validade local vencida.
Medir a renovação de verdade exige esperar a expiração real (uma hora) ou mover
o relógio do convidado, e ficou fora desta rodada.

**Ressalva sobre o passo 2.** A primeira tentativa de entrar voltou "E-mail ou
senha incorretos" (`400` no GoTrue). A causa foi da automação, não do app: um
`adb shell input tap` calculado para o botão caiu sobre o teclado virtual e
acrescentou um dígito ao campo de senha. A tentativa seguinte, com o campo
refeito, entrou. Fica registrado para que ninguém leia o `400` do log do
contêiner como falha de produto.

## Ambiente e comandos

- Emulador: AVD `Pixel_8_Pro`, Android 15, serial `emulator-5554`, sem janela,
  iniciado por `scripts/e2e-emulator.sh start Pixel_8_Pro emulator-5554 America/Fortaleza <log>`
  e endurecido por `scripts/e2e-emulator.sh harden emulator-5554`.
- Backend: `scripts/local-supabase.sh up` — Supabase local em
  `http://127.0.0.1:54321` visto do host e em `http://10.0.2.2:54321` visto de
  dentro do emulador, que é o alias do loopback do host na rede do QEMU.
- App: `cd app && flutter build apk --debug --flavor dev -t lib/main_dev.dart --dart-define-from-file=config/local.json`,
  instalado com `adb -s emulator-5554 install -r -t app/build/app/outputs/flutter-apk/app-dev-debug.apk`.
- Prints: `adb -s emulator-5554 exec-out screencap -p > <arquivo>.png`.
- `scripts/e2e-local.sh` não foi usado: ele só conhece o roteiro da feature 001
  e recusa a 002. Esta rodada é medição manual instrumentada por `adb`, e os
  rótulos deste relatório seguem o mesmo formato que o `scripts/verify-gauntlet.sh`
  cobra.

## Rastro

Tudo o que a rodada tocou fora do repositório: o AVD `Pixel_8_Pro` (app
instalado, sessão gravada, sistema reiniciado uma vez, preferências editadas no
passo 5) e a stack Supabase local em contêiner, com a conta `e2e@ganza.local`
criada pelo próprio `scripts/local-supabase.sh`. Dentro do repositório, além
desta pasta, só o arquivo ignorado pelo git `app/config/local.json`, escrito
pelo script da stack.

## Limpeza no wrap

`scripts/e2e-emulator.sh cleanup` derruba o emulador desta rodada e
`scripts/local-supabase.sh down` apaga a stack local com os volumes e remove
`app/config/local.json` e `infra/local/.runtime.env`. O APK depurável fica em
`app/build/`, que não é versionado. Nada foi escrito em homologação nem em
produção.

**Veredito: a sessão sobreviveu aos dois casos — continuou logada depois de `am force-stop` e nova abertura, e continuou logada depois de `adb reboot` e nova abertura, sem pedir credencial em nenhum dos dois.**
