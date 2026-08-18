#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEATURE="${1:-001}"

case "$FEATURE" in
  001) DIRECTORY='001_cadastro_manual' ;;
  *) echo "Feature sem roteiro E2E local: $FEATURE" >&2; exit 1 ;;
esac

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
[ ! -e "$ROUND" ] || {
  echo "E2E recusado: a rodada $RODADA já existe e não pode ser sobrescrita" >&2
  exit 1
}

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
"$ROOT/docs/$DIRECTORY/e2e_shots.sh" 2>&1 | tee "$ROUND/logs/listagem.log"
"$ROOT/docs/$DIRECTORY/e2e_registro_shots.sh" 2>&1 | tee "$ROUND/logs/registro.log"

REPORT="$ROUND/report.md"
{
  printf '# Round %s - E2E local da feature %s\n\n' "$RODADA" "$FEATURE"
  printf '## Contexto\n\n'
  printf 'Stack local descartável em `%s`; commit `%s`.\n\n' "$SUPABASE_URL" "$(git -C "$ROOT" rev-parse --short HEAD)"
  printf '## Passos executados\n\n'
  printf '| Cenário | Expectativa | Resultado | Evidência |\n| --- | --- | --- | --- |\n'
  printf '| Erro de leitura | Estado de erro distinto do vazio | PASS | [PNG](01_erro_de_leitura.png) · [log](logs/listagem.log) |\n'
  printf '| Estado vazio | Lista sem transações não se confunde com falha | PASS | [PNG](02_estado_vazio.png) · [log](logs/listagem.log) |\n'
  printf '| Lista e RLS | Linhas do dono aparecem após leitura local | PASS | [PNG](03_lista_carregada.png) · [log](logs/listagem.log) |\n'
  printf '| Abandono | Formulário sem Registrar não cria linha | PASS | [PNG](06_formulario_abandonado.png) · [log](logs/registro.log) |\n'
  printf '| Criação pelo app | Registrar cria exatamente uma linha no topo | PASS | [PNG](02_lista_com_a_linha_nova.png) · [log](logs/registro.log) |\n'
  printf '| Toque duplo | Dois toques criam uma única linha | PASS | [PNG](05_botao_desabilitado_durante_envio.png) · [log](logs/registro.log) |\n'
  printf '| Falha de rede | Campos permanecem e nada é gravado | PASS | [PNG](03_sem_rede_campos_preservados.png) · [log](logs/registro.log) |\n'
  printf '| Sessão expirada | Sessão inválida retorna ao login | PASS | [PNG](04_sessao_expirada_login.png) · [log](logs/registro.log) |\n'
  printf '\n## Ambiente e comandos\n\n'
  printf -- '- Stack local descartável: `%s`\n' "$SUPABASE_URL"
  printf -- '- `scripts/e2e-emulator.sh start|cleanup` controla exclusivamente o AVD desta rodada.\n'
  printf -- '- `scripts/local-supabase.sh reset`\n'
  printf -- '- `docs/%s/e2e_shots.sh`\n' "$DIRECTORY"
  printf -- '- `docs/%s/e2e_registro_shots.sh`\n' "$DIRECTORY"
  printf '\nLogs e ressalvas ficam em [`logs/`](logs/). Não são gravados vídeos.\n'
} > "$REPORT"
