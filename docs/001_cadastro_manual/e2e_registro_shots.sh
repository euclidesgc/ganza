#!/usr/bin/env bash
#
# E2E do registro de transação — Fase 4 (T4.7) de docs/001_cadastro_manual.
# Irmão de `e2e_shots.sh` (rodada 01, leitura): mesma mecânica de emulador,
# fuso e limpeza; cenas diferentes. Gera TODOS os prints do DoD por máquina.
# Ao dev humano sobra conferir as imagens.
#
#   uso:  ./docs/001_cadastro_manual/e2e_registro_shots.sh
#         ./docs/001_cadastro_manual/e2e_registro_shots.sh down    # só limpa
#
# Pré-requisitos (exportados antes de rodar):
#   SUPABASE_URL  ANON_KEY  JWT_DONO  USER_ID
#
# ── RASTRO QUE ESTE SCRIPT DEIXA (tudo removido por `down`, que também roda
#    no trap EXIT) ───────────────────────────────────────────────────────────
#   • emulador Android `Pixel_8_Pro` headless          → controller por PID
#   • saída para o Supabase local bloqueada em 'sem_rede' → iptables -D
#   • latência forçada na cena 'duplo'                 → emu network delay none
#   • app instalado no emulador (br.com.ganza.ganza)   → fica; morre com o AVD
#   • processos `patrol test`                          → pkill no trap
#
# Este roteiro só aceita a stack local descartável iniciada por
# `scripts/local-supabase.sh`. Dados de HML e produção nunca são alterados.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP="$RAIZ/app"
RODADA="${RODADA:-02}"
DESTINO="$RAIZ/docs/001_cadastro_manual/e2e/round_$RODADA"
AVD="${AVD:-Pixel_8_Pro}"
SERIAL="${SERIAL:-emulator-5554}"
LOGS="$DESTINO/logs"
FUSO="${FUSO:-America/Sao_Paulo}"
EVIDENCE_PORT="${E2E_EVIDENCE_PORT:-8765}"
EVIDENCE_PID=''
PATROL_PID=''
EMULATOR_OWNED=0

export PATH="$PATH:$HOME/.puro/shared/pub_cache/bin:$HOME/.pub-cache/bin:${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools:${ANDROID_HOME:-$HOME/Android/Sdk}/emulator"

falhas=0
ok()   { printf 'PASS  %s\n' "$*"; }
nok()  { printf 'FAIL  %s\n' "$*"; falhas=$((falhas + 1)); }
etapa(){ printf '\n── %s\n' "$*"; }

bloquear_supabase_local() {
  adb -s "$SERIAL" root >/dev/null
  adb -s "$SERIAL" wait-for-device
  adb -s "$SERIAL" reverse "tcp:$EVIDENCE_PORT" "tcp:$EVIDENCE_PORT" >/dev/null
  adb -s "$SERIAL" shell iptables -I OUTPUT -d 10.0.2.2 -j REJECT >/dev/null
  adb -s "$SERIAL" shell iptables -C OUTPUT -d 10.0.2.2 -j REJECT >/dev/null
}

liberar_supabase_local() {
  adb -s "$SERIAL" shell iptables -D OUTPUT -d 10.0.2.2 -j REJECT 2>/dev/null
}

# ─────────────────────────────────────────────────────────────── limpeza ──
down() {
  etapa 'limpeza'
  if [ -n "$PATROL_PID" ]; then
    kill -TERM -- "-$PATROL_PID" 2>/dev/null || true
    wait "$PATROL_PID" 2>/dev/null || true
  fi
  if [ -n "$EVIDENCE_PID" ]; then
    kill "$EVIDENCE_PID" 2>/dev/null || true
    wait "$EVIDENCE_PID" 2>/dev/null || true
  fi
  if [ "$EMULATOR_OWNED" -eq 1 ]; then
    adb -s "$SERIAL" reverse --remove "tcp:$EVIDENCE_PORT" 2>/dev/null
    adb -s "$SERIAL" emu network delay none 2>/dev/null
    liberar_supabase_local
    "$RAIZ/scripts/e2e-emulator.sh" stop
  fi
}

if [ "${1:-run}" = 'down' ]; then down; exit 0; fi
trap down EXIT

# ────────────────────────────────────────────────────────── pré-requisitos ──
etapa 'pré-requisitos'
for var in SUPABASE_URL ANON_KEY JWT_DONO USER_ID; do
  [ -n "${!var:-}" ] || { nok "variável $var não exportada"; exit 1; }
done
case "$SUPABASE_URL" in
  http://127.0.0.1:*|http://localhost:*|http://0.0.0.0:*) ;;
  *) nok "SUPABASE_URL remoto recusado: $SUPABASE_URL"; exit 1 ;;
esac
for bin in adb emulator patrol curl python3; do
  command -v "$bin" >/dev/null || { nok "binário ausente: $bin"; exit 1; }
done
ok 'ambiente completo'

mkdir -p "$DESTINO" "$LOGS"
python3 "$RAIZ/scripts/capture-e2e-evidence.py" \
  --port "$EVIDENCE_PORT" --serial "$SERIAL" --destination "$DESTINO" \
  > "$LOGS/captura.log" 2>&1 &
EVIDENCE_PID=$!
for _ in $(seq 1 20); do
  curl -fsS "http://127.0.0.1:$EVIDENCE_PORT/health" >/dev/null && break
  sleep 1
done
curl -fsS "http://127.0.0.1:$EVIDENCE_PORT/health" >/dev/null \
  && ok 'servidor de captura pronto' \
  || { nok 'servidor de captura não iniciou'; exit 1; }

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

contar() {
  api GET '/rest/v1/transactions?select=id' | sed '$d' \
    | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))'
}

define_b64() {
  printf '%s' "$1" | base64 | tr -d '\n'
}

# ─────────────────────────────────────── o que a tela terá de mostrar ──
# Calculado FORA do app, para que o esperado não venha do mesmo formatador
# que está sob prova. Fuso do host e do emulador são o mesmo (o script aborta
# se o emulador não estiver em America/Sao_Paulo), então "ontem" é o mesmo dia.
DIA_ONTEM="$(python3 -c "
import datetime
print((datetime.date.today() - datetime.timedelta(days=1)).day)
")"
DATA_ONTEM="$(python3 -c "
import datetime
dias = ['segunda','terça','quarta','quinta','sexta','sábado','domingo']
d = datetime.date.today() - datetime.timedelta(days=1)
print('%02d/%02d, %s' % (d.day, d.month, dias[d.weekday()]))
")"
ok "ontem é dia $DIA_ONTEM, e a tela tem de escrever '$DATA_ONTEM'"

# Token vencido para a cena da sessão expirada. A assinatura é falsa de
# propósito: este token nunca chega ao servidor — o cliente só lê o `exp` dele
# para concluir que precisa renovar. Quem vai ao GoTrue é o refresh token
# inválido, e é a recusa dele (400) que apaga a sessão.
JWT_EXPIRADO="$(python3 -c "
import base64, json, os, time
def b64(o):
    bruto = json.dumps(o, separators=(',', ':')).encode()
    return base64.urlsafe_b64encode(bruto).decode().rstrip('=')
agora = int(time.time())
cabecalho = b64({'alg': 'HS256', 'typ': 'JWT'})
corpo = b64({
    'sub': os.environ['USER_ID'], 'role': 'authenticated',
    'aud': 'authenticated', 'iat': agora - 86400, 'exp': agora - 3600,
})
print(cabecalho + '.' + corpo + '.assinatura-invalida-de-proposito')
")"
ok 'JWT vencido forjado para a cena da sessão expirada'

SEED_RECENTE='Café'
SEED_ANTIGA='Venda da feira'
DESCRICAO='Almoço'
DIGITOS='4500'
VALOR_CAMPO='R$ 45,00'
VALOR_LISTA='−R$ 45,00'
DESCRICAO_DUPLO='Toque duplo'
DIGITOS_DUPLO='1000'
VALOR_CAMPO_DUPLO='R$ 10,00'
VALOR_LISTA_DUPLO='−R$ 10,00'

# ───────────────────────────────────────────────────────────── emulador ──
etapa 'emulador'
if ! "$RAIZ/scripts/e2e-emulator.sh" start "$AVD" "$SERIAL" "$FUSO" "$LOGS/emulador.log"; then
  nok 'não foi possível reservar um emulador exclusivo para a rodada'
  exit 1
fi
EMULATOR_OWNED=1
adb wait-for-device
for _ in $(seq 1 60); do
  [ "$(adb -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = '1' ] && break
  sleep 5
done
[ "$(adb -s "$SERIAL" shell getprop sys.boot_completed | tr -d '\r')" = '1' ] \
  && ok "emulador $AVD pronto (API $(adb -s "$SERIAL" shell getprop ro.build.version.sdk | tr -d '\r'))" \
  || { nok 'emulador não subiu'; exit 1; }

adb -s "$SERIAL" reverse "tcp:$EVIDENCE_PORT" "tcp:$EVIDENCE_PORT" >/dev/null

# ─────────────────────────────────────────────────────── fuso do emulador ──
# Não é detalhe de ambiente: "ontem" só é ontem se o aparelho vive no mesmo
# fuso de quem calcula o esperado. Aborta se não conseguir fixar.
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
  nok "fuso do emulador é '$(fuso_atual)', esperava $FUSO — 'ontem' não valeria"
  exit 1
fi

# ────────────────────────────────────────────── contrato antes da tela ──
etapa 'contrato — RLS e leitura pelo PostgREST'
anon="$(curl -sS "$SUPABASE_URL/rest/v1/transactions?select=id" -H "apikey: $ANON_KEY")"
[ "$anon" = '[]' ] \
  && ok 'GET anônimo devolve [] — a RLS barra quem não tem sessão' \
  || nok "GET anônimo devolveu: $anon"

resposta="$(api GET '/rest/v1/transactions?select=id,description,amount,direction,occurred_at,source&order=occurred_at.desc')"
codigo="$(printf '%s' "$resposta" | tail -1)"
corpo="$(printf '%s' "$resposta" | sed '$d')"
[ "$codigo" = '200' ] && ok 'GET do dono devolve 200' || nok "GET do dono devolveu $codigo"
# Numa reexecução, o primeiro snapshot é o que vale: ele é o único registro do
# que existia antes de a rodada apagar qualquer coisa.
if [ -s "$DESTINO/estado_inicial.json" ]; then
  printf '%s\n' "$corpo" | python3 -m json.tool > "$DESTINO/estado_antes_da_reexecucao.json"
  ok "estado anterior já existia; reexecução salva em estado_antes_da_reexecucao.json"
else
  printf '%s\n' "$corpo" | python3 -m json.tool > "$DESTINO/estado_inicial.json"
  ok "estado anterior salvo em rodada_$RODADA/estado_inicial.json"
fi

# ───────────────────────────────────────── estado de partida conhecido ──
etapa 'partida — tabela da conta esvaziada por id e semeada com duas linhas antigas'
# Os ids vêm da leitura recém-feita (não do arquivo), para que uma reexecução
# apague também o que a execução anterior criou.
mapfile -t ids < <(printf '%s\n' "$corpo" | python3 -c "
import json,sys
linhas = json.load(sys.stdin)
if len(linhas) > 10:
    sys.exit('linhas demais (%d) — abortando por segurança' % len(linhas))
for l in linhas:
    if l['source'] != 'manual':
        sys.exit('linha de origem inesperada: %s' % l['source'])
    print(l['id'])
")
for id in "${ids[@]}"; do
  [ -n "$id" ] || continue
  cod="$(api DELETE "/rest/v1/transactions?id=eq.$id" | tail -1)"
  [ "$cod" = '204' ] && ok "apagada $id" || nok "DELETE de $id devolveu $cod"
done
[ "$(contar)" = '0' ] && ok 'tabela da conta vazia' || nok "tabela não esvaziou"

# As duas linhas antigas existem por um motivo só: dar com quem a linha do app
# disputar o topo. Elas nascem pela Edge Function (nunca por SQL) e são de
# dias anteriores a ontem.
criar() { # <direção in|out> <descrição> <centavos> <occurred_at>
  local resposta codigo corpo
  resposta="$(curl -sS -X POST "$SUPABASE_URL/functions/v1/transactions" \
    -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT_DONO" \
    -H 'Content-Type: application/json' \
    -d "{\"direction\":\"$1\",\"amount\":$3,\"description\":\"$2\",\"occurred_at\":\"$4\"}" \
    -w '\n%{http_code}')"
  codigo="$(printf '%s' "$resposta" | tail -1)"
  corpo="$(printf '%s' "$resposta" | sed '$d')"
  [ "$codigo" = '201' ] \
    && ok "semeada '$2' ($4)" \
    || nok "POST de '$2' devolveu $codigo: $corpo"
}
criar out "$SEED_RECENTE"  700   '2026-08-12T09:00:00-03:00'
criar in  "$SEED_ANTIGA"   25000 '2026-08-10T10:00:00-03:00'
c_partida="$(contar)"
[ "$c_partida" = '2' ] && ok 'duas linhas antigas na conta' || nok "esperava 2, achei $c_partida"

api GET '/rest/v1/transactions?select=description,amount,direction,occurred_at&order=occurred_at.desc' \
  | sed '$d' | python3 -m json.tool > "$DESTINO/linhas_semeadas.json"

# ──────────────────────────────────────────────────────────────── cenas ──
cena() { # <nome> <descrição> <dígitos> <valor no campo> <valor na lista> <png…>
  local nome="$1" descricao="$2" digitos="$3" campo="$4" lista="$5"
  shift 5
  ( cd "$APP" && exec setsid timeout --kill-after=30s 300 patrol test \
      --target=patrol_test/registro_transacao_test.dart \
      --device "$SERIAL" --flavor dev \
      --dart-define-from-file=config/local.json \
      --dart-define="E2E_CENA=$nome" \
      --dart-define="E2E_EVIDENCE_URL=http://127.0.0.1:$EVIDENCE_PORT" \
      --dart-define="E2E_JWT=$JWT_DONO" \
      --dart-define="E2E_JWT_EXPIRADO=$JWT_EXPIRADO" \
      --dart-define="E2E_USER_ID=$USER_ID" \
      --dart-define="E2E_EMAIL=e2e@ganza.local" \
      --dart-define="E2E_DESCRICAO_B64=$(define_b64 "$descricao")" \
      --dart-define="E2E_DIGITOS=$digitos" \
      --dart-define="E2E_VALOR_CAMPO_B64=$(define_b64 "$campo")" \
      --dart-define="E2E_VALOR_LISTA_B64=$(define_b64 "$lista")" \
      --dart-define="E2E_DIA_ONTEM=$DIA_ONTEM" \
      --dart-define="E2E_DATA_ONTEM_B64=$(define_b64 "$DATA_ONTEM")" \
      --dart-define="E2E_SEED_RECENTE_B64=$(define_b64 "$SEED_RECENTE")" \
      --dart-define="E2E_SEED_ANTIGA_B64=$(define_b64 "$SEED_ANTIGA")" ) \
    > "$LOGS/cena_$nome.log" 2>&1 &
  PATROL_PID=$!
  wait "$PATROL_PID"
  local saida=$? faltou=0
  PATROL_PID=''
  for png in "$@"; do
    [ -s "$DESTINO/$png.png" ] || faltou=1
  done
  if [ $saida -eq 0 ] && [ $faltou -eq 0 ]; then
    ok "cena '$nome' — Patrol verde e print(s): $*"
  else
    nok "cena '$nome' — saída $saida; ver logs/cena_$nome.log"
  fi
}

# ── 1. Nada é gravado sem toque em Registrar (invariante nº 1 do CLAUDE.md) ──
etapa 'cena abandono · formulário preenchido e abandonado sem tocar em Registrar'
c_abandono_antes="$(contar)"
cena abandono "$DESCRICAO" "$DIGITOS" "$VALOR_CAMPO" "$VALOR_LISTA" \
  06_formulario_abandonado
c_abandono_depois="$(contar)"
[ "$c_abandono_antes" = "$c_abandono_depois" ] \
  && ok "count antes=$c_abandono_antes, depois=$c_abandono_depois — nada gravado" \
  || nok "count mudou de $c_abandono_antes para $c_abandono_depois SEM toque em Registrar"

# ── 2. Caminho feliz, registrado pelo app ──
etapa 'cena feliz · formulário preenchido → Registrar → lista com a linha nova no topo'
c_feliz_antes="$(contar)"
cena feliz "$DESCRICAO" "$DIGITOS" "$VALOR_CAMPO" "$VALOR_LISTA" \
  01_formulario_preenchido 02_lista_com_a_linha_nova
c_feliz_depois="$(contar)"
[ "$c_feliz_depois" = "$((c_feliz_antes + 1))" ] \
  && ok "count antes=$c_feliz_antes, depois=$c_feliz_depois — exatamente uma linha nova" \
  || nok "count foi de $c_feliz_antes para $c_feliz_depois"

# ── 3. A linha que o app gravou, conferida no banco (decisão A1) ──
etapa 'banco · a linha criada pelo app, logo após o print'
api GET '/rest/v1/transactions?select=amount,source,direction,user_id,area_id,description,occurred_at,reconciliation_status,created_at&order=created_at.desc&limit=1' \
  | sed '$d' | python3 -m json.tool > "$DESTINO/linha_registrada.json"
if python3 -c "
import json, os, sys
l = json.load(open('$DESTINO/linha_registrada.json'))[0]
assert l['description'] == '$DESCRICAO', l['description']
assert isinstance(l['amount'], int), type(l['amount'])
assert l['amount'] == 4500, l['amount']
assert l['source'] == 'manual', l['source']
assert l['direction'] == 'out', l['direction']
assert l['user_id'] == os.environ['USER_ID'], l['user_id']
assert l['area_id'] is None, l['area_id']
"; then
  ok "amount=4500 inteiro (não 4499), source=manual, direction=out, user_id do dono, area_id nulo"
else
  nok 'a linha gravada não bate com o contrato — ver linha_registrada.json'
fi

# ── 4. Botão desabilitado em voo e toque duplo que não duplica ──
etapa 'cena duplo · botão desabilitado durante o envio, com dois toques'
# Latência forçada para que o print alcance o estado em voo: sem isso a
# resposta volta antes do PixelCopy e o print mostraria a lista.
adb -s "$SERIAL" emu network delay gprs >/dev/null 2>&1 \
  && ok 'latência gprs aplicada no emulador' \
  || echo '  (emu network delay indisponível — seguindo sem latência forçada)'
c_duplo_antes="$(contar)"
cena duplo "$DESCRICAO_DUPLO" "$DIGITOS_DUPLO" "$VALOR_CAMPO_DUPLO" "$VALOR_LISTA_DUPLO" \
  05_botao_desabilitado_durante_envio
c_duplo_depois="$(contar)"
adb -s "$SERIAL" emu network delay none >/dev/null 2>&1
[ "$c_duplo_depois" = "$((c_duplo_antes + 1))" ] \
  && ok "count antes=$c_duplo_antes, depois=$c_duplo_depois — dois toques, uma linha" \
  || nok "toque duplo gerou $((c_duplo_depois - c_duplo_antes)) linha(s)"

# ── 5. Falha (a): sem rede ──
etapa 'cena sem_rede · envio sem Supabase local'
c_semrede_antes="$(contar)"
bloquear_supabase_local \
  && ok 'saída do emulador para o Supabase local bloqueada' \
  || { nok 'não foi possível bloquear o Supabase local'; exit 1; }
cena sem_rede "$DESCRICAO" "$DIGITOS" "$VALOR_CAMPO" "$VALOR_LISTA" \
  03_sem_rede_campos_preservados
liberar_supabase_local
ok 'saída para o Supabase local restaurada'
c_semrede_depois="$(contar)"
[ "$c_semrede_antes" = "$c_semrede_depois" ] \
  && ok "count antes=$c_semrede_antes, depois=$c_semrede_depois — falha não grava" \
  || nok "count mudou de $c_semrede_antes para $c_semrede_depois numa falha de rede"

# ── 6. Falha (b): sessão expirada ──
etapa 'cena sessao_expirada · token vencido, renovação recusada'
cena sessao_expirada "$DESCRICAO" "$DIGITOS" "$VALOR_CAMPO" "$VALOR_LISTA" \
  04_sessao_expirada_login
c_final="$(contar)"

# ─────────────────────────────────────────────────────── snapshot + README ──
etapa 'snapshot dos scripts na rodada'
cp "$RAIZ/docs/001_cadastro_manual/e2e_registro_shots.sh"   "$DESTINO/e2e_registro_shots.sh.snapshot"
cp "$APP/patrol_test/registro_transacao_test.dart"          "$DESTINO/registro_transacao_test.dart.snapshot"
ok 'scripts congelados na pasta da rodada'

python3 - <<PY > "$DESTINO/contagens.json"
import json
print(json.dumps({
    'partida_apos_limpeza_e_seed': $c_partida,
    'abandono': {'antes': $c_abandono_antes, 'depois': $c_abandono_depois},
    'caminho_feliz': {'antes': $c_feliz_antes, 'depois': $c_feliz_depois},
    'toque_duplo': {'antes': $c_duplo_antes, 'depois': $c_duplo_depois},
    'sem_rede': {'antes': $c_semrede_antes, 'depois': $c_semrede_depois},
    'final': $c_final,
}, indent=2, ensure_ascii=False))
PY
ok 'contagens salvas em contagens.json'

etapa 'README da rodada'
cat > "$DESTINO/README.md" <<README
# Rodada $RODADA — E2E do registro pelo app (Fase 4 · T4.7)

Gerado por \`docs/001_cadastro_manual/e2e_registro_shots.sh\` em $(date '+%d/%m/%Y %H:%M')
— emulador \`$AVD\` (Android API $(adb -s "$SERIAL" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r'),
fuso \`$(fuso_atual)\`), build \`--flavor dev\` contra o Supabase local.
Nenhum print foi tirado à mão e nenhuma linha desta rodada nasceu de \`curl\`:
o formulário é preenchido dígito a dígito e o botão **Registrar** é tocado pelo
executor Patrol, sem interação manual.

O fuso do aparelho é parte da prova: "ontem" só é ontem se o emulador vive no
mesmo fuso de quem calculou o esperado. O script fixa \`$FUSO\` no boot e
**aborta** se não conseguir.

**O atestado é do dev humano.** O QA gerou; quem confere as imagens é você.

## O que cada arquivo prova

| arquivo | o que prova |
| --- | --- |
| \`01_formulario_preenchido.png\` | O formulário com **Despesa** (default, rótulo textual visível), **$VALOR_CAMPO** no campo de valor — digitado dígito a dígito, entrando pela direita —, **$DESCRICAO** na descrição e **$DATA_ONTEM** (ontem) no seletor de data. O botão **Registrar** está habilitado; o teste afirma que ele estava **desabilitado** com o formulário vazio. |
| \`02_lista_com_a_linha_nova.png\` | Depois do toque em **Registrar**: o formulário saiu de cena e a lista foi **refeita pelo PostgREST** (não houve inserção local). A linha nova aparece **no topo**, acima de \`$SEED_RECENTE\` e \`$SEED_ANTIGA\` — o teste compara as coordenadas verticais, não confia no olho. Valor \`$VALOR_LISTA\` e data \`$DATA_ONTEM\`. |
| \`03_sem_rede_campos_preservados.png\` | Envio com saída para o Supabase local bloqueada por \`iptables\`. O formulário mostra **"Sem conexão com o servidor."** — a mensagem nova da T4.2; o teste afirma que **"Algo deu errado. Tente de novo." não aparece em lugar nenhum**. E os campos continuam preenchidos: o teste lê os \`controller\` do valor e da descrição e o rótulo da data **depois** do erro. |
| \`04_sessao_expirada_login.png\` | Sessão expirada → o app está **no login**, não numa mensagem de erro. O teste afirma a ausência de "Algo deu errado. Tente de novo." **e** de "Sua sessão expirou. Entre de novo." — não é um banner disfarçado, é outra tela. |
| \`03\` + \`04\` juntos | Os dois modos de falha em **estados visualmente distintos**: um mantém o formulário com tudo no lugar e uma mensagem curta; o outro troca de tela. |
| \`05_botao_desabilitado_durante_envio.png\` | Com o envio em voo, o botão vira **"Registrando…"** e o teste lê \`onPressed == null\` — desabilitado de fato, não só apagado. O print é tirado **entre** o primeiro e o segundo toque (latência \`gprs\` forçada no emulador para o estado durar o suficiente). |
| \`06_formulario_abandonado.png\` | Formulário inteiro preenchido e abandonado pelo botão de voltar, **sem** tocar em Registrar — o estado que a contagem abaixo prova não ter virado linha. |
| \`linha_registrada.json\` | A linha que **o app** gravou, lida pelo PostgREST logo após o print \`02\`. |
| \`linhas_semeadas.json\` | As duas linhas antigas plantadas pela Edge Function antes da rodada, para que a linha do app tenha com quem disputar o topo. |
| \`estado_inicial.json\` | Fotografia da tabela **antes** de qualquer DELETE — os ids apagados estão aqui. |
| \`contagens.json\` | Todos os \`count(*)\` antes/depois desta rodada, na ordem em que rodaram. |
| \`logs/\` | Saída completa de cada cena e do emulador. |
| \`*.snapshot\` | Cópia congelada dos scripts e do teste que produziram exatamente estas imagens. |

## A linha do banco, conferida e não assumida (decisão A1)

Equivalente ao \`select amount, source, direction, user_id, area_id from
public.transactions order by created_at desc limit 1\` do DoD, feito pelo
PostgREST com o JWT do dono logo após o print \`02\` (ver \`linha_registrada.json\`):

\`\`\`json
$(python3 -c "
import json
l = json.load(open('$DESTINO/linha_registrada.json'))[0]
print(json.dumps(l, indent=2, ensure_ascii=False))
" 2>/dev/null)
\`\`\`

- \`amount\` é **4500**, inteiro — nunca \`4499\`, que é o que \`double.parse('45,00') * 100\` produziria.
- \`source\` é **manual**, \`direction\` é **out**, \`user_id\` é o da conta do dono.
- \`area_id\` é **nulo** — a decisão A1 (transação nasce sem área) verificada no banco.

## As contagens (\`select count(*)\`)

| momento | antes | depois |
| --- | --- | --- |
| formulário preenchido e **abandonado** (invariante nº 1) | $c_abandono_antes | $c_abandono_depois |
| caminho feliz (um toque em Registrar) | $c_feliz_antes | $c_feliz_depois |
| **toque duplo** no botão | $c_duplo_antes | $c_duplo_depois |
| envio **sem rede** | $c_semrede_antes | $c_semrede_depois |

Partida: $c_partida linhas (tabela esvaziada por id e semeada com duas linhas
antigas). Final: $c_final linhas na conta do dono — $((c_final - c_partida)) criadas
pelo app nesta rodada, para a limpeza manual da T5.1 (risco X6 do plano).

## Como a sessão expirada foi induzida

Com o formulário preenchido, o teste chama
\`auth.setSession('refresh-token-invalidado-pelo-e2e', accessToken: <JWT com exp no passado>)\`.
É o mesmo caminho que o cliente percorre sozinho quando o access token vence:
ele lê o \`exp\`, conclui que precisa renovar, pede a renovação ao GoTrue,
recebe **400**, apaga a sessão e emite \`signedOut\`. O \`refreshListenable\` do
\`go_router\` reavalia o \`redirect\` e leva ao \`/entrar\`. O JWT forjado tem
assinatura inválida de propósito — ele **nunca** vai ao servidor; quem vai é o
refresh token, e é a recusa dele que derruba a sessão.

## O que o olho tem de julgar (não vira asserção)

1. O formulário preenchido está **legível e na ordem do \`02_specs.md\` §6.1** —
   direção, valor, descrição, data — e o valor tem destaque tipográfico (\`01\`).
2. A mensagem de falha sem rede é **curta e cabe numa linha**, e o formulário
   continua parecendo um formulário, não uma tela de erro (\`03\`).
3. O login (\`04\`) não tem resíduo do formulário nem mensagem de erro pendurada.
4. O botão em voo (\`05\`) **parece** desabilitado — contraste e rótulo — e não
   apenas "sem cor".
5. A linha nova no topo (\`02\`) não empurrou o layout: valores continuam
   alinhados à direita, com algarismos tabulares.
README
ok 'README.md da rodada emitido'

etapa 'resultado'
if [ "$falhas" -eq 0 ]; then
  echo "✓ rodada $RODADA verde — evidências em $DESTINO"
else
  echo "✗ rodada $RODADA com $falhas falha(s)"
fi
exit "$falhas"
