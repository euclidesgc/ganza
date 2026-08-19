#!/usr/bin/env bash
#
# E2E da listagem de transações — Fase 3 (T3.8) de docs/01-cadastro-manual.
# Gera TODOS os prints do DoD por máquina. Ao dev humano sobra conferir as
# imagens; nenhum passo é operado à mão.
#
#   uso:  RODADA=01 ./docs/01-cadastro-manual/e2e_shots.sh
#         ./docs/01-cadastro-manual/e2e_shots.sh down    # só limpa
#
# Pré-requisitos (exportados antes de rodar):
#   SUPABASE_URL  ANON_KEY  JWT_DONO  USER_ID
#
# ── RASTRO QUE ESTE SCRIPT DEIXA (tudo removido por `down`, que também roda
#    no trap EXIT) ───────────────────────────────────────────────────────────
#   • emulador Android `Pixel_8_Pro` headless          → adb emu kill
#   • ~/.gradle/init.d/ganza-e2e.gradle                → rm
#   • rede do emulador desligada na cena 1             → svc wifi/data enable
#   • app instalado no emulador (br.com.ganza.ganza)   → fica; morre com o AVD
#   • processos `flutter drive`                        → pkill no trap
#
# ── O QUE ELE NÃO FAZ, E POR QUÊ ──────────────────────────────────────────────
# A skill `instrumentar-e2e` manda subir base efêmera (`docker compose down -v`)
# e jamais apontar para produção. Aqui não há base local: a D3/D7 travou um
# único ambiente remoto. Consequência assumida e registrada: o script escreve
# no Supabase de produção, mas só nas linhas da própria conta do dono, sempre
# por id explícito, nunca por filtro amplo, com snapshot do estado anterior
# salvo em `estado_inicial.json` antes de qualquer DELETE — e aborta se
# encontrar mais linhas do que as que ele mesmo planta.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="$RAIZ/app"
RODADA="${RODADA:-01}"
DESTINO="$RAIZ/docs/01-cadastro-manual/evidencias/rodada_$RODADA"
AVD="${AVD:-Pixel_8_Pro}"
SERIAL="${SERIAL:-emulator-5554}"
PACOTE="br.com.ganza.ganza"
INIT_GRADLE="$HOME/.gradle/init.d/ganza-e2e.gradle"
LOGS="$DESTINO/logs"
FUSO="${FUSO:-America/Sao_Paulo}"

export PATH="$PATH:${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools:${ANDROID_HOME:-$HOME/Android/Sdk}/emulator"

falhas=0
ok()   { printf 'PASS  %s\n' "$*"; }
nok()  { printf 'FAIL  %s\n' "$*"; falhas=$((falhas + 1)); }
etapa(){ printf '\n── %s\n' "$*"; }

# ─────────────────────────────────────────────────────────────── limpeza ──
down() {
  etapa 'limpeza'
  pkill -f 'flutter_tools.snapshot drive' 2>/dev/null
  adb -s "$SERIAL" shell svc wifi enable  2>/dev/null
  adb -s "$SERIAL" shell svc data enable  2>/dev/null
  rm -f "$INIT_GRADLE"
  adb -s "$SERIAL" emu kill 2>/dev/null
  sleep 2
  adb devices | grep -q "$SERIAL" && echo "  emulador ainda listado (encerrando)" || echo "  emulador encerrado"
  echo "  init.d removido: $INIT_GRADLE"
}

if [ "${1:-run}" = 'down' ]; then down; exit 0; fi
trap down EXIT

# ────────────────────────────────────────────────────────── pré-requisitos ──
etapa 'pré-requisitos'
for var in SUPABASE_URL ANON_KEY JWT_DONO USER_ID; do
  [ -n "${!var:-}" ] || { nok "variável $var não exportada"; exit 1; }
done
for bin in adb emulator flutter curl python3; do
  command -v "$bin" >/dev/null || { nok "binário ausente: $bin"; exit 1; }
done
ok 'ambiente completo'

mkdir -p "$DESTINO" "$LOGS"

api() { # <método> <caminho> [corpo]
  local metodo="$1" caminho="$2" corpo="${3:-}"
  if [ -n "$corpo" ]; then
    curl -sS -X "$metodo" "$SUPABASE_URL$caminho" \
      -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT_DONO" \
      -H 'Content-Type: application/json' -d "$corpo" -w '\n%{http_code}'
  else
    curl -sS -X "$metodo" "$SUPABASE_URL$caminho" \
      -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT_DONO" -w '\n%{http_code}'
  fi
}

# ───────────────────────────────────────────────────────────── emulador ──
etapa 'emulador'
if ! adb devices | grep -q "${SERIAL}[[:space:]]*device"; then
  # `-timezone` no boot: a lista renderiza a data no fuso do aparelho, e a
  # prova do fix de fuso (linha guardada em 01:30Z de 16/08, vivida às 22:30
  # de 15/08) só existe se o emulador estiver em America/Sao_Paulo.
  nohup emulator -avd "$AVD" -no-window -no-audio -no-boot-anim \
    -timezone "$FUSO" \
    -gpu swiftshader_indirect -no-snapshot > "$LOGS/emulador.log" 2>&1 &
  adb wait-for-device
fi
for _ in $(seq 1 60); do
  [ "$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = '1' ] && break
  sleep 5
done
[ "$(adb -s "$SERIAL" shell getprop sys.boot_completed | tr -d '\r')" = '1' ] \
  && ok "emulador $AVD pronto (API $(adb -s "$SERIAL" shell getprop ro.build.version.sdk | tr -d '\r'))" \
  || { nok 'emulador não subiu'; exit 1; }

adb -s "$SERIAL" shell svc wifi enable >/dev/null 2>&1
adb -s "$SERIAL" shell svc data enable >/dev/null 2>&1

# ─────────────────────────────────────────────────────── fuso do emulador ──
# Não é detalhe de ambiente: é o que a cena 3 prova. Se o aparelho estivesse
# em UTC, a linha de 01:30Z sairia como "16/08, domingo" e o print estaria
# mentindo sobre a correção. Aborta se não conseguir fixar o fuso.
etapa 'fuso do emulador'
fuso_atual() { adb -s "$SERIAL" shell getprop persist.sys.timezone | tr -d '\r'; }
if [ "$(fuso_atual)" != "$FUSO" ]; then
  adb -s "$SERIAL" root >/dev/null 2>&1
  adb -s "$SERIAL" wait-for-device
  adb -s "$SERIAL" shell setprop persist.sys.timezone "$FUSO" >/dev/null 2>&1
  sleep 2
fi
if [ "$(fuso_atual)" = "$FUSO" ]; then
  ok "emulador em $FUSO ($(adb -s "$SERIAL" shell date | tr -d '\r'))"
else
  nok "fuso do emulador é '$(fuso_atual)', esperava $FUSO — a prova de fuso não valeria"
  exit 1
fi

install -D -m 644 "$RAIZ/docs/01-cadastro-manual/e2e_gradle_init.gradle" "$INIT_GRADLE"
ok 'init.d do Gradle instalado (força espresso 3.6.1 — ver e2e_gradle_init.gradle)'

# ────────────────────────────────────────────── contrato antes da tela ──
# O que a máquina consegue afirmar sozinha fica aqui; a tela só é chamada
# para o que exige olho.
etapa 'contrato — RLS e leitura pelo PostgREST'

anon="$(curl -sS "$SUPABASE_URL/rest/v1/transactions?select=id" -H "apikey: $ANON_KEY")"
[ "$anon" = '[]' ] \
  && ok "GET anônimo devolve [] — a RLS barra quem não tem sessão" \
  || nok "GET anônimo devolveu: $anon"

resposta="$(api GET '/rest/v1/transactions?select=id,description,amount,direction,occurred_at,source&order=occurred_at.desc')"
codigo="$(printf '%s' "$resposta" | tail -1)"
corpo="$(printf '%s' "$resposta" | sed '$d')"
[ "$codigo" = '200' ] && ok 'GET do dono devolve 200' || nok "GET do dono devolveu $codigo"

printf '%s\n' "$corpo" | python3 -m json.tool > "$DESTINO/estado_inicial.json"
ok "estado anterior salvo em $(basename "$DESTINO")/estado_inicial.json"

# ───────────────────────────────────── cena 1 · erro de leitura (sem rede) ──
# Vem primeiro porque não depende de dado nenhum, e porque a cena seguinte
# precisa da tabela vazia.
cena() { # <nome> <arquivo>
  local nome="$1" arquivo="$2"
  ( cd "$APP" && E2E_DESTINO="$DESTINO" timeout 900 flutter drive \
      --driver=test_driver/integration_test.dart \
      --target=integration_test/lista_transacoes_test.dart \
      -d "$SERIAL" --flavor prod \
      --dart-define-from-file=config/prod.json \
      --dart-define="E2E_CENA=$nome" \
      --dart-define="E2E_ARQUIVO=$arquivo" \
      --dart-define="E2E_JWT=$JWT_DONO" \
      --dart-define="E2E_USER_ID=$USER_ID" \
      --dart-define="E2E_EMAIL=euclides.catunda@gmail.com" ) \
    > "$LOGS/cena_$nome.log" 2>&1
  local saida=$?
  if [ $saida -eq 0 ] && [ -s "$DESTINO/$arquivo.png" ]; then
    ok "cena '$nome' — asserções verdes e print em $arquivo.png"
  else
    nok "cena '$nome' — saída $saida; ver logs/cena_$nome.log"
  fi
}

etapa 'cena 1 · erro de leitura com a rede do emulador derrubada'
adb -s "$SERIAL" shell svc wifi disable
adb -s "$SERIAL" shell svc data disable
sleep 5
adb -s "$SERIAL" shell ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 \
  && nok 'emulador ainda tem rede — a cena de erro não provaria nada' \
  || ok 'rede do emulador derrubada'
cena erro 01_erro_de_leitura
adb -s "$SERIAL" shell svc wifi enable
adb -s "$SERIAL" shell svc data enable
for _ in $(seq 1 20); do
  adb -s "$SERIAL" shell ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && break
  sleep 3
done
ok 'rede do emulador restaurada'

# ───────────────────────────────────────────────── cena 2 · estado vazio ──
etapa 'cena 2 · estado vazio (tabela da conta esvaziada por id)'
mapfile -t ids < <(python3 -c "
import json,sys
linhas = json.load(open('$DESTINO/estado_inicial.json'))
if len(linhas) > 10:
    sys.exit('linhas demais (%d) — abortando por segurança' % len(linhas))
for l in linhas:
    if l['source'] != 'manual':
        sys.exit('linha de origem inesperada: %s' % l['source'])
    print(l['id'])
")
[ ${#ids[@]} -gt 0 ] || ok 'nada a apagar — tabela já estava vazia'
for id in "${ids[@]}"; do
  [ -n "$id" ] || continue
  cod="$(api DELETE "/rest/v1/transactions?id=eq.$id" | tail -1)"
  [ "$cod" = '204' ] && ok "apagada $id" || nok "DELETE de $id devolveu $cod"
done
vazia="$(api GET '/rest/v1/transactions?select=id' | sed '$d')"
[ "$vazia" = '[]' ] && ok 'tabela da conta vazia' || nok "ainda há linhas: $vazia"
cena vazio 02_estado_vazio

# ────────────────────────────────────────────── cena 3 · lista carregada ──
# Recriadas pela Edge Function real (o caminho de escrita do produto), nunca
# por SQL: o que a Fase 4 vai exercitar pelo formulário é este mesmo endpoint.
etapa 'cena 3 · lista carregada (linhas recriadas pela Edge Function)'
criar() { # <direção in|out> <descrição> <centavos> <occurred_at>
  local resposta codigo corpo
  resposta="$(curl -sS -X POST "$SUPABASE_URL/functions/v1/transactions" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT_DONO" \
    -H 'Content-Type: application/json' \
    -d "{\"direction\":\"$1\",\"amount\":$3,\"description\":\"$2\",\"occurred_at\":\"$4\"}" \
    -w '\n%{http_code}')"
  codigo="$(printf '%s' "$resposta" | tail -1)"
  corpo="$(printf '%s' "$resposta" | sed '$d')"
  if [ "$codigo" = '201' ] && printf '%s' "$corpo" | python3 -c "
import json,sys
l = json.load(sys.stdin)
assert isinstance(l['amount'], int) and l['amount'] == $3, l['amount']
assert l['direction'] == '$1', l['direction']
assert l['source'] == 'manual', l['source']
assert l['reconciliation_status'] == 'pending', l['reconciliation_status']
assert l['user_id'] == '$USER_ID', l['user_id']
"; then
    ok "Edge Function criou '$2' com direction=$1, amount=$3 inteiro, source=manual"
  else
    nok "POST de '$2' devolveu $codigo: $corpo"
  fi
}
# O seed é desenhado para que UMA lista prove as três coisas de uma vez:
#
#  • fuso  — 'Venda de sábado à noite' é guardada em 2026-08-16T01:30Z, que em
#            America/Sao_Paulo é 22:30 do dia 15. Tem de sair '15/08, sábado';
#            com o bug de formatar em UTC sairia '16/08, domingo'. É a única
#            linha de 15/08 na lista, para não haver dúvida de qual é a prova.
#  • sinal — ela é `in`: prefixo '+' e cor de entrada, ao lado das saídas.
#  • coluna — o maior valor (+R$ 1.234.567,89) fica LOGO ACIMA do menor
#            (−R$ 7,00), com sinais opostos: é onde a coluna dançaria se a
#            fonte não tivesse algarismos tabulares, e onde '+' e '−' revelam
#            se ocupam a mesma largura.
#
# Ordem da lista = occurred_at desc; as três datas são distintas o bastante
# para o empate por created_at não entrar em jogo.
criar in  'Venda de sábado à noite' 123456789 '2026-08-16T01:30:00+00:00'
criar out 'Café'                    700       '2026-08-14T09:00:00-03:00'
criar out 'Almoço'                  4500      '2026-08-14T08:00:00-03:00'

total="$(api GET '/rest/v1/transactions?select=id' | sed '$d' | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')"
[ "$total" = '3' ] && ok 'três linhas na conta' || nok "esperava 3 linhas, achei $total"

# O que o banco guardou, ao lado do que a tela mostra: é assim que o dev
# humano confere o fuso sem abrir o Postgres — 2026-08-16T01:30:00+00:00 no
# JSON, '15/08, sábado' no print.
api GET '/rest/v1/transactions?select=description,amount,direction,occurred_at&order=occurred_at.desc' \
  | sed '$d' | python3 -m json.tool > "$DESTINO/linhas_semeadas.json"
ok "linhas semeadas salvas em $(basename "$DESTINO")/linhas_semeadas.json"

cena lista 03_lista_carregada

# ───────────────────────────────────── recorte dos algarismos tabulares ──
# Imagem derivada, não uma tela nova: a mesma captura de 03, ampliada na
# coluna de valores, que é o detalhe que o olho tem de julgar.
etapa 'recorte da coluna de valores'
python3 - "$DESTINO/03_lista_carregada.png" "$DESTINO/04_algarismos_tabulares.png" <<'PY'
import sys
from PIL import Image

origem, destino = sys.argv[1], sys.argv[2]
img = Image.open(origem)
l, a = img.size
recorte = img.crop((int(l * 0.28), int(a * 0.11), l, int(a * 0.39)))
recorte = recorte.resize((recorte.width * 2, recorte.height * 2), Image.LANCZOS)
recorte.save(destino)
print(f'recorte {recorte.size[0]}x{recorte.size[1]} de {origem}')
PY
[ -s "$DESTINO/04_algarismos_tabulares.png" ] \
  && ok 'recorte 04_algarismos_tabulares.png gerado a partir de 03' \
  || nok 'recorte não saiu'

# ─────────────────────────────────────────────────────── snapshot + README ──
etapa 'snapshot dos scripts na rodada'
cp "$RAIZ/docs/01-cadastro-manual/e2e_shots.sh"            "$DESTINO/e2e_shots.sh.snapshot"
cp "$RAIZ/docs/01-cadastro-manual/e2e_gradle_init.gradle"  "$DESTINO/e2e_gradle_init.gradle.snapshot"
cp "$APP/integration_test/lista_transacoes_test.dart"      "$DESTINO/lista_transacoes_test.dart.snapshot"
cp "$APP/test_driver/integration_test.dart"                "$DESTINO/integration_test_driver.dart.snapshot"
ok 'scripts congelados na pasta da rodada'

etapa 'README da rodada'
# Emitido aqui, não escrito à mão: é por ele que o dev humano confere, e um
# README desatualizado descreveria uma imagem que não existe mais.
cat > "$DESTINO/README.md" <<README
# Rodada $RODADA — E2E da listagem de transações (Fase 3 · T3.8)

Gerado por \`docs/01-cadastro-manual/e2e_shots.sh\` em $(date '+%d/%m/%Y %H:%M')
— emulador \`$AVD\` (Android API $(adb -s "$SERIAL" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r'),
fuso \`$(fuso_atual)\`), build \`--flavor prod\` contra o Supabase de produção.
Nenhum print foi tirado à mão: o app é dirigido por \`integration_test\` e a
captura sai do driver.

O fuso do aparelho é parte da prova, não do ambiente: a lista formata a data
no fuso de quem lê. O script fixa \`$FUSO\` no boot e **aborta** se não
conseguir — um print tirado num emulador em UTC não provaria o fuso.

**O atestado é do dev humano.** O QA gerou; quem confere as imagens é você.

## O que cada arquivo prova

| arquivo | o que prova |
| --- | --- |
| \`01_erro_de_leitura.png\` | Com a rede do emulador derrubada (\`svc wifi/data disable\`), a lista mostra ícone de erro, mensagem e o botão **Tentar de novo**. O teste também afirma que o texto do estado vazio **não** aparece aqui. |
| \`02_estado_vazio.png\` | Conta sem nenhuma transação (todas apagadas por id, ver \`estado_inicial.json\`): **"Nenhuma transação registrada."**, sem ilustração e sem entusiasmo. O teste afirma que **"Tentar de novo" não aparece**. |
| \`01\` + \`02\` juntos | Falha e vazio são telas **visivelmente diferentes** — o \`prd.md\` proíbe que um erro se disfarce de "nada aqui". Duas imagens, dois estados. |
| \`03_lista_carregada.png\` | Lista com as três linhas recriadas **pela Edge Function real** (\`POST /functions/v1/transactions\`, nunca por SQL). Prova quatro coisas na mesma imagem: **(a) fuso** — \`Venda de sábado à noite\` está guardada como \`2026-08-16T01:30:00+00:00\` (ver \`linhas_semeadas.json\`) e aparece como **\`15/08, sábado\`**, o dia que o usuário viveu às 22:30; formatada em UTC sairia \`16/08, domingo\`. **(b) entrada** — a mesma linha é \`direction: "in"\` e vem com **\`+\`** e a cor de entrada, ao lado de duas saídas em \`−\` e cor de saída. **(c) valor e data no formato do DoD** — \`Almoço\`, \`14/08, sexta\`, \`−R$ 45,00\` à direita, com o menos tipográfico (−, U+2212). **(d) volta** — a \`AppBar\` tem a seta de voltar para Áreas (rota empilhada por \`pushNamed\`). |
| \`04_algarismos_tabulares.png\` | **Recorte ampliado 2× da mesma captura de \`03\`** (não é outra tela), na coluna de valores: \`+R\$ 1.234.567,89\` imediatamente acima de \`−R\$ 7,00\`, e \`−R\$ 45,00\` abaixo. O maior e o menor valor colados, com **sinais opostos**: é onde a coluna dançaria se a fonte não tivesse \`FontFeature.tabularFigures()\` (T3.2), e onde se vê se o \`+\` e o \`−\` ocupam a mesma largura. |
| \`linhas_semeadas.json\` | O que o banco guardou nesta rodada — \`occurred_at\` em UTC ao lado do que o print mostra. É por aqui que se confere o fuso sem abrir o Postgres. |
| \`estado_inicial.json\` | Fotografia da tabela **antes** de qualquer DELETE — os ids apagados estão aqui. |
| \`logs/\` | Saída completa de cada cena e do emulador. |
| \`*.snapshot\` | Cópia congelada dos scripts e do teste que produziram exatamente estas imagens. |

O DoD escreve a data como \`15/08, sexta\`: é a **forma** (\`dd/MM, dia-da-semana\`),
não o calendário — 15/08/2026 cai num sábado. A rodada mostra as duas metades
com datas reais, \`15/08, sábado\` e \`14/08, sexta\`.

## O que o olho tem de julgar (não vira asserção)

1. Os três valores terminam na **mesma vertical** e os algarismos têm a mesma
   largura entre linhas, com \`+\` e \`−\` alinhados (\`04\`).
2. A cor da entrada e a da saída se distinguem **sem depender de cor** — o
   \`+\`/\`−\` textual está lá — e nenhuma das duas some no fundo.
3. O vazio é **neutro** — nada de confete, ilustração ou convite animado.
4. O erro **parece** erro: cor, ícone e ação de saída visíveis.
5. A descrição fica em uma linha, com reticências se estourar.

## Achados desta rodada (não bloqueiam o DoD)

1. **Mensagem de erro genérica sem rede.** Em \`01\`, sem conexão nenhuma, o app
   diz "Algo deu errado. Tente de novo." em vez de algo como "Sem conexão".
   O estado está correto e distinto do vazio (que é o que o DoD exige), mas a
   mensagem não ajuda o usuário a agir.
README
ok 'README.md da rodada emitido'

etapa 'resultado'
if [ "$falhas" -eq 0 ]; then
  echo "✓ rodada $RODADA verde — evidências em $DESTINO"
else
  echo "✗ rodada $RODADA com $falhas falha(s)"
fi
exit "$falhas"
