#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEATURE="${1:-001}"

case "$FEATURE" in
  001)
    DIRECTORY='001_cadastro_manual'
    ROTEIROS=('docs/001_cadastro_manual/e2e_shots.sh' 'docs/001_cadastro_manual/e2e_registro_shots.sh')
    NOMES_DE_LOG=('listagem' 'registro')
    RODADA_DA_FEATURE=''
    ;;
  002)
    DIRECTORY='002_conta_e_configuracoes'
    ROTEIROS=('scripts/e2e-002-auth.sh')
    NOMES_DE_LOG=('auth')
    # A rodada 02 desta feature já recebeu os prints das tarefas de
    # implementação da Fase 1; o E2E da fase completa a mesma pasta em vez de
    # abrir uma terceira, que separaria evidências do mesmo PR.
    RODADA_DA_FEATURE='02'
    ;;
  *) echo "Feature sem roteiro E2E local: $FEATURE" >&2; exit 1 ;;
esac

if [ -z "${RODADA:-}" ] && [ -n "$RODADA_DA_FEATURE" ]; then
  RODADA="$RODADA_DA_FEATURE"
fi

if [ -z "${RODADA:-}" ]; then
  for candidate in 01 02 03; do
    [ ! -e "$ROOT/docs/$DIRECTORY/e2e/round_$candidate" ] && { RODADA="$candidate"; break; }
  done
fi

[ -n "${RODADA:-}" ] || {
  echo "E2E recusado: máximo de três rodadas já existe para a feature $FEATURE" >&2
  exit 1
}

case "$RODADA" in
  01|02|03) ;;
  *) echo "E2E recusado: RODADA deve estar entre 01 e 03" >&2; exit 1 ;;
esac

ROUND="$ROOT/docs/$DIRECTORY/e2e/round_$RODADA"
# O que uma rodada fechada não aceita é ser sobrescrita. Uma que terminou em
# falha não é evidência de nada e pode ser refeita no lugar.
if [ -f "$ROUND/report.md" ] && ! grep -q '\*\*FALHA\*\*' "$ROUND/report.md"; then
  echo "E2E recusado: a rodada $RODADA já está fechada e não pode ser sobrescrita" >&2
  exit 1
fi

cleanup() {
  "$ROOT/scripts/e2e-emulator.sh" cleanup || true
  "$ROOT/scripts/local-supabase.sh" down || true
}

trap cleanup EXIT INT TERM
"$ROOT/scripts/e2e-emulator.sh" cleanup
"$ROOT/scripts/local-supabase.sh" reset

set -a
. "$ROOT/infra/local/.runtime.env"
set +a

case "$SUPABASE_URL" in
  http://127.0.0.1:*|http://localhost:*|http://0.0.0.0:*) ;;
  *) echo "E2E recusado: SUPABASE_URL não é local ($SUPABASE_URL)" >&2; exit 1 ;;
esac

export SUPABASE_URL ANON_KEY JWT_DONO USER_ID
export RODADA

mkdir -p "$ROUND/logs"
STATUS=0
for indice in "${!ROTEIROS[@]}"; do
  [ "$STATUS" = '0' ] || break
  if ! bash "$ROOT/${ROTEIROS[$indice]}" 2>&1 | tee "$ROUND/logs/${NOMES_DE_LOG[$indice]}.log"; then
    STATUS=1
  fi
done

# O report descreve o que o log registrou. Um template com PASS fixo descreve
# o que se esperava, e um dia diverge do que aconteceu sem ninguém notar.
linhas_de_cena() {
  grep -hE "^(PASS|FAIL)[[:space:]]+cena '" "$ROUND"/logs/*.log 2>/dev/null || true
}

evidencia_da_linha() {
  printf '%s' "$1" | grep -oE '[0-9]{2}_[a-z_]+(\.png)?' | sort -u | while read -r arquivo; do
    case "$arquivo" in *.png) ;; *) arquivo="$arquivo.png" ;; esac
    printf '[%s](%s) ' "$arquivo" "$arquivo"
  done
}

PRIMEIRO_LOG="logs/${NOMES_DE_LOG[0]}.log"

REPORT="$ROUND/report.md"
{
  printf '# Round %s - E2E local da feature %s\n\n' "$RODADA" "$FEATURE"
  printf '## Contexto\n\n'
  printf 'Stack local descartável em `%s`; commit `%s`.\n\n' "$SUPABASE_URL" "$(git -C "$ROOT" rev-parse --short HEAD)"
  if [ "$STATUS" = '0' ]; then
    printf 'Resultado: **VERDE** — %s cenas, nenhuma falha.\n\n' "$(linhas_de_cena | grep -c '^PASS' || true)"
  else
    printf 'Resultado: **FALHA** — a rodada não pode ser usada como evidência de DoD.\n'
    printf 'Cenas que não constam da tabela abaixo não chegaram a rodar; o motivo\n'
    printf 'está no fim dos arquivos de [`logs/`](logs/).\n\n'
  fi
  printf '## Passos executados\n\n'
  printf '| Cena | Resultado | Evidência |\n| --- | --- | --- |\n'
  if [ -z "$(linhas_de_cena)" ]; then
    printf '| — | nenhuma cena chegou a rodar | [log](%s) |\n' "$PRIMEIRO_LOG"
  else
    linhas_de_cena | while IFS= read -r linha; do
      printf '| %s | %s | %s|\n' \
        "$(printf '%s' "$linha" | sed -n "s/.*cena '\([^']*\)'.*/\1/p")" \
        "${linha%% *}" \
        "$(evidencia_da_linha "$linha")"
    done
  fi
  if [ -f "$ROUND/contagens.json" ]; then
    printf '\nContagens da tabela antes e depois de cada cena, como o roteiro as\n'
    printf 'leu do banco: [`contagens.json`](contagens.json). A linha criada pelo\n'
    printf 'app está em [`linha_registrada.json`](linha_registrada.json).\n'
  fi
  if [ -f "$ROUND/mensagens_capturadas.json" ]; then
    printf '\nAs mensagens que o capturador local recebeu para o endereço desta\n'
    printf 'execução, sem token e sem código:\n'
    printf '[`mensagens_capturadas.json`](mensagens_capturadas.json).\n'
  fi
  printf '\n## Ambiente e comandos\n\n'
  printf -- '- Stack local descartável: `%s`\n' "$SUPABASE_URL"
  printf -- '- `scripts/e2e-emulator.sh start|cleanup` controla exclusivamente o AVD desta rodada.\n'
  printf -- '- `scripts/local-supabase.sh reset`\n'
  for roteiro in "${ROTEIROS[@]}"; do
    printf -- '- `%s`\n' "$roteiro"
  done
  printf '\nLogs e ressalvas ficam em [`logs/`](logs/). Não são gravados vídeos.\n'
} > "$REPORT"

exit "$STATUS"
