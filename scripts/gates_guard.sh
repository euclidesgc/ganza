#!/usr/bin/env bash
#
# Guard-script dos Gates de qualidade (rede de segurança automática do CI).
# bash + grep puro, ZERO dependência Dart — cobre o que é mecanicamente
# detectável dos Gates 1 e 4. Os Gates 2 e 3 (tier de widget, arquivo gordo)
# são heurísticos demais para grep confiável e ficam no gate de revisão.
#
# Sai 0 se limpo, 1 se achar violação. Plugado no .github/workflows/ci.yml.
#
# Escapes pontuais (com justificativa) por comentário na própria linha:
#   // gate1-ok: <motivo>
#   // gate4-ok: <motivo>
#
# Isenções por caminho:
#   - app/lib/core/theme/   é a FONTE dos tokens (Color(0x) vive aqui). A
#                           isenção é do caminho exato, não de qualquer pasta
#                           chamada "theme".
#   - test/                 testes podem usar literais.
#   - patrol_test/          idem.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET_LIBS=("app/lib")
fail=0

[ -d "app/lib" ] || { echo "✓ gates_guard: app/lib ainda não existe — nada a verificar."; exit 0; }

mapfile -t FILES < <(find "${TARGET_LIBS[@]}" -name '*.dart' | grep -v '/core/theme/' | sort)

emit() { # <GATE> <file:line> <trecho>
  printf '  [%s] %s\n      %s\n' "$1" "$2" "$3"
  fail=1
}

for f in "${FILES[@]}"; do
  # -------------------------------------------------------------------------
  # GATE 1 — nenhuma função/método que retorna Widget/List<Widget>.
  # Permitidos: build(), static pageBuilder(), e escape // gate1-ok.
  # (Callbacks itemBuilder/builder: são ARGUMENTOS, não declarações.)
  # -------------------------------------------------------------------------
  while IFS=$'\t' read -r line content; do
    [ -z "${line:-}" ] && continue
    case "$content" in
      *"Widget build("*|*"static Widget pageBuilder("*|*"// gate1-ok"*) continue ;;
    esac
    emit "GATE1" "$f:$line" "$(printf '%s' "$content" | sed 's/^[[:space:]]*//')"
  done < <(grep -nE '^[[:space:]]*(static )?(Widget|List<Widget>) _?[a-zA-Z0-9]+ ?\(' "$f" \
             | sed -E 's/^([0-9]+):/\1\t/')

  # -------------------------------------------------------------------------
  # GATE 4 — zero literal de estilo cru (deve vir de core/theme via token).
  # Cobre: Color(0x…), Colors.<nome> (menos white/black/transparent),
  # fontSize: <num>, (Border)Radius.circular(<num>), EdgeInsets.*(<num>).
  # Escape // gate4-ok libera a linha.
  # -------------------------------------------------------------------------
  while IFS=$'\t' read -r line content; do
    [ -z "${line:-}" ] && continue
    case "$content" in *"// gate4-ok"*) continue ;; esac
    emit "GATE4" "$f:$line" "$(printf '%s' "$content" | sed 's/^[[:space:]]*//')"
  done < <(grep -nE \
             'Color\(0x|\bColors\.[a-zA-Z]|fontSize: ?-?[0-9]|circular\( ?-?[0-9]|EdgeInsets\.(all|fromLTRB)\( ?-?[0-9]|EdgeInsets\.(symmetric|only)\([^)]*: ?-?[0-9]' "$f" \
             | grep -vE '\bColors\.(white|black|transparent)\b' \
             | sed -E 's/^([0-9]+):/\1\t/')
done

echo ""
if [ "$fail" -ne 0 ]; then
  echo "✗ gates_guard: violação(ões) acima. Tokenize em app/lib/core/theme/ ou justifique com // gateN-ok: <motivo>."
  exit 1
fi
echo "✓ gates_guard: Gates 1 e 4 limpos em ${TARGET_LIBS[*]}."
exit 0
