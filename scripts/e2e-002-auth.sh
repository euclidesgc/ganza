#!/usr/bin/env bash
#
# E2E de cadastro e recuperação de senha — Fase 1 (T1.10/T1.11) de
# docs/002_conta_e_configuracoes. Orquestra o roteiro
# `app/patrol_test/conta_e_recuperacao_test.dart`: uma cena por invocação do
# Patrol, prints gerados pela máquina, nenhum toque manual.
#
#   uso:  bash scripts/e2e-002-auth.sh
#         bash scripts/e2e-002-auth.sh down    # só limpa
#
# Pré-requisitos (exportados antes de rodar, o que `scripts/e2e-local.sh 002`
# já faz a partir de infra/local/.runtime.env):
#   SUPABASE_URL  ANON_KEY
#
# ── RASTRO QUE ESTE SCRIPT DEIXA (tudo removido por `down`, que também roda no
#    trap EXIT) ───────────────────────────────────────────────────────────────
#   • emulador Android `Pixel_8_Pro` headless          → controller por PID
#   • adb reverse da porta do capturador de prints     → adb reverse --remove
#   • app instalado no emulador (br.com.ganza.ganza)   → fica; morre com o AVD
#   • processos `patrol test`                          → pkill no trap
#   • uma conta nova no GoTrue LOCAL, endereço sorteado nesta execução → morre
#     com `scripts/local-supabase.sh down`
#
# Este roteiro só aceita a stack local descartável iniciada por
# `scripts/local-supabase.sh`. Dados de HML e produção nunca são alterados.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$RAIZ/app"
RODADA="${RODADA:-02}"
DESTINO="$RAIZ/docs/002_conta_e_configuracoes/e2e/round_$RODADA"
AVD="${AVD:-Pixel_8_Pro}"
SERIAL="${SERIAL:-emulator-5554}"
LOGS="$DESTINO/logs"
FUSO="${FUSO:-America/Sao_Paulo}"
EVIDENCE_PORT="${E2E_EVIDENCE_PORT:-8765}"
MAILPIT_HOST="${E2E_MAILPIT_HOST:-http://127.0.0.1:54325}"
MAILPIT_NO_APARELHO="${E2E_MAILPIT_DEVICE:-http://10.0.2.2:54325}"
EVIDENCE_PID=''
PATROL_PID=''
EMULATOR_OWNED=0

# O GoTrue recusa dois e-mails para o mesmo endereço dentro da janela de
# `GOTRUE_SMTP_MAX_FREQUENCY` (um minuto). O cadastro e o pedido de recuperação
# desta rodada são para o MESMO endereço, então o segundo espera a janela
# fechar — sem isto a cena de recuperação falharia por
# `over_email_send_rate_limit`, que não é o que ela prova.
JANELA_DE_EMAIL="${E2E_JANELA_EMAIL:-70}"
ULTIMO_EMAIL=0

export PATH="$PATH:$HOME/.puro/shared/pub_cache/bin:$HOME/.pub-cache/bin:${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools:${ANDROID_HOME:-$HOME/Android/Sdk}/emulator"

falhas=0
ok()   { printf 'PASS  %s\n' "$*"; }
nok()  { printf 'FAIL  %s\n' "$*"; falhas=$((falhas + 1)); }
etapa(){ printf '\n── %s\n' "$*"; }

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
    "$RAIZ/scripts/e2e-emulator.sh" stop
  fi
}

if [ "${1:-run}" = 'down' ]; then down; exit 0; fi
trap down EXIT

# ────────────────────────────────────────────────────────── pré-requisitos ──
etapa 'pré-requisitos'
for var in SUPABASE_URL ANON_KEY; do
  [ -n "${!var:-}" ] || { nok "variável $var não exportada"; exit 1; }
done
for alvo in "$SUPABASE_URL" "$MAILPIT_HOST" "$MAILPIT_NO_APARELHO"; do
  case "$alvo" in
    http://127.0.0.1:*|http://localhost:*|http://0.0.0.0:*|http://10.0.2.2:*) ;;
    *) nok "alvo remoto recusado: $alvo"; exit 1 ;;
  esac
done
for bin in adb emulator patrol curl python3; do
  command -v "$bin" >/dev/null || { nok "binário ausente: $bin"; exit 1; }
done
curl -fsS "$MAILPIT_HOST/api/v1/info" >/dev/null \
  && ok 'capturador de e-mail local no ar' \
  || { nok "capturador de e-mail não respondeu em $MAILPIT_HOST"; exit 1; }
ok 'ambiente completo'

# ─────────────────────────────────────────── endereço próprio da execução ──
# Sem dígitos de propósito: o código de seis dígitos é extraído do corpo da
# mensagem, e um endereço numerado apareceria lá como candidato falso.
ENDERECO="${E2E_ENDERECO:-e2e-$(LC_ALL=C tr -dc 'a-z' < /dev/urandom | head -c 12)@ganza.local}"
ok "endereço desta execução: $ENDERECO"

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

# ───────────────────────────────────────────────────────────────── emulador ──
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

"$RAIZ/scripts/e2e-emulator.sh" harden "$SERIAL"
ok 'diálogos de erro do sistema suprimidos — nenhum ANR tapa os prints'

adb -s "$SERIAL" reverse "tcp:$EVIDENCE_PORT" "tcp:$EVIDENCE_PORT" >/dev/null

# ──────────────────────────────────── a conta não existe antes da rodada ──
etapa 'partida — o endereço da execução ainda não tem conta'
entrada="$(curl -sS -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ENDERECO\",\"password\":\"ganza-local-primeira\"}" \
  -o /dev/null -w '%{http_code}')"
[ "$entrada" = '400' ] \
  && ok "entrar antes de cadastrar devolve $entrada — o endereço está livre" \
  || nok "entrar antes de cadastrar devolveu $entrada, esperava 400"

aguardar_janela_de_email() {
  local decorrido=$(( $(date +%s) - ULTIMO_EMAIL ))
  [ "$ULTIMO_EMAIL" -eq 0 ] && return 0
  if [ "$decorrido" -lt "$JANELA_DE_EMAIL" ]; then
    local resta=$(( JANELA_DE_EMAIL - decorrido ))
    printf '  aguardando %ss para o servidor aceitar outro e-mail para o mesmo endereço\n' "$resta"
    sleep "$resta"
  fi
}

# ───────────────────────────────────────────────────────────────── cenas ──
cena() { # <nome> <png…>
  local nome="$1"
  shift
  ( cd "$APP" && exec setsid timeout --kill-after=60s 900 patrol test \
      --target=patrol_test/conta_e_recuperacao_test.dart \
      --device "$SERIAL" --flavor dev \
      --dart-define-from-file=config/local.json \
      --dart-define="E2E_CENA=$nome" \
      --dart-define="E2E_EVIDENCE_URL=http://127.0.0.1:$EVIDENCE_PORT" \
      --dart-define="E2E_MAILPIT_URL=$MAILPIT_NO_APARELHO" \
      --dart-define="E2E_ENDERECO=$ENDERECO" ) \
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

etapa 'cena criar_conta · cadastro pela tela, sem sessão no fim'
cena criar_conta 10_conta_criada_confirme_email
ULTIMO_EMAIL="$(date +%s)"

etapa 'cena entrar_sem_confirmar · a conta existe e mesmo assim não entra'
cena entrar_sem_confirmar 11_entrar_sem_confirmar

etapa 'cena confirmar_e_entrar · token da mensagem capturada, depois login pela tela'
cena confirmar_e_entrar 12_dentro_do_app_com_a_conta_nova 13_email_lembrado_apos_sair

etapa 'cena recuperar_senha · código errado, código certo, senha trocada'
aguardar_janela_de_email
cena recuperar_senha \
  14_codigo_errado_recusado 15_nova_senha_apos_codigo_certo \
  16_dentro_do_app_apos_trocar_a_senha 17_senha_antiga_recusada \
  18_entrar_com_a_senha_nova

# ─────────────────────────── o que o servidor viu, sem token nem senha ──
etapa 'servidor · a conta da rodada, conferida pelo caminho público'
antiga="$(curl -sS -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ENDERECO\",\"password\":\"ganza-local-primeira\"}" \
  -o /dev/null -w '%{http_code}')"
nova="$(curl -sS -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ENDERECO\",\"password\":\"ganza-local-trocada\"}" \
  -o /dev/null -w '%{http_code}')"
[ "$antiga" = '400' ] \
  && ok "a senha do cadastro não entra mais ($antiga)" \
  || nok "a senha antiga ainda entra ($antiga)"
[ "$nova" = '200' ] \
  && ok "a senha definida na recuperação entra ($nova)" \
  || nok "a senha nova não entra ($nova)"

python3 - "$DESTINO/mensagens_capturadas.json" "$MAILPIT_HOST" "$ENDERECO" <<'PY'
import json
import re
import sys
import urllib.request

destino, capturador, endereco = sys.argv[1:4]

SEM_LINKS = re.compile(r'https?://\S+')
CODIGO = re.compile(r'(?<![0-9])[0-9]{6}(?![0-9])')


def buscar(caminho):
    with urllib.request.urlopen(f'{capturador}{caminho}') as resposta:
        return json.load(resposta)


resumo = []
for mensagem in buscar('/api/v1/messages?limit=50')['messages']:
    if endereco not in [contato['Address'] for contato in mensagem['To']]:
        continue
    corpo = buscar(f"/api/v1/message/{mensagem['ID']}")
    texto = corpo.get('Text') or ''
    resumo.append({
        'assunto': mensagem['Subject'],
        'recebida_em': mensagem['Created'],
        'tipo': 'signup' if 'type=signup' in texto else 'recovery',
        'traz_link_com_token': 'token=' in texto,
        'traz_codigo_de_seis_digitos': bool(
            CODIGO.search(SEM_LINKS.sub(' ', texto))
        ),
    })

with open(destino, 'w', encoding='utf-8') as arquivo:
    json.dump(resumo, arquivo, indent=2, ensure_ascii=False)
print(f'{len(resumo)} mensagem(ns) capturada(s) para o endereço da rodada')
PY
ok 'mensagens da rodada resumidas em mensagens_capturadas.json (sem token e sem código)'

etapa 'resultado'
if [ "$falhas" -eq 0 ]; then
  echo "✓ rodada $RODADA verde — evidências em $DESTINO"
else
  echo "✗ rodada $RODADA com $falhas falha(s)"
fi
exit "$falhas"
