#!/usr/bin/env bash
#
# Guard-script dos Gates de qualidade (rede de segurança automática do CI).
# bash + grep puro, ZERO dependência Dart — cobre o que é mecanicamente
# detectável dos Gates 1 e 4, mais a checagem de rota nomeada órfã. Os
# Gates 2 e 3 (tier de widget, arquivo gordo) são heurísticos demais para
# grep confiável e ficam no gate de revisão.
#
# Gate 4 cobre também Icons.<nome> cru (ícone deve vir de AppIcons em
# core/theme/). Padrão ancorado (^|[^A-Za-z])Icons\. para não acusar
# AppIcons.<nome>, que é o token exigido.
#
# ROTA ÓRFÃ — toda constante `static const <ident>Name = '...'` declarada
# em app/lib/**/*_routes.dart precisa de pelo menos uma referência de
# navegação por nome (goNamed/pushNamed/replaceNamed/pushReplacementNamed
# ou equivalente — qualquer `.<algo>Named(`) em algum lugar de app/lib.
# Conta tanto a forma qualificada (`XRoutes.fooName` dentro de uma chamada
# Named em qualquer arquivo) quanto o idioma de wrapper estático que o
# próprio arquivo de rotas usa (`context.pushNamed(name)` dentro do mesmo
# `_routes.dart`, sem qualificar a classe) — só para esse caso o
# identificador nu conta, e só dentro do arquivo que o declara, para não
# confundir `name` de uma rota com `name` de outra.
#
# Sai 0 se limpo, 1 se achar violação. Plugado no .github/workflows/ci.yml.
#
# Escapes pontuais (com justificativa) por comentário na própria linha:
#   // gate1-ok: <motivo>
#   // gate4-ok: <motivo>
#   // rota-sem-consumidor-ok: <motivo>   (só para rota alcançada apenas
#     por redirect da guarda de rota, nunca por toque — ex.: a rota raiz,
#     que só é atingida pelo initialLocation e pelo fallback do redirect)
#
# Isenções por caminho:
#   - app/lib/core/theme/   é a FONTE dos tokens (Color(0x) vive aqui). A
#                           isenção é do caminho exato, não de qualquer pasta
#                           chamada "theme". Não precisa de isenção equivalente
#                           para Icons.<nome>: app_icons.dart só declara
#                           IconData(0x…) tipado, nunca Icons.<nome> cru.
#                           A checagem de rota órfã NÃO tem essa isenção —
#                           roda sobre todo app/lib, inclusive core/theme.
#   - test/                 testes podem usar literais.
#   - patrol_test/          idem.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET_LIBS=("app/lib")
fail=0

[ -d "app/lib" ] || { echo "✓ gates_guard: app/lib ainda não existe — nada a verificar."; exit 0; }

mapfile -t FILES < <(find "${TARGET_LIBS[@]}" -name '*.dart' | grep -v '/core/theme/' | sort)
mapfile -t ALL_DART < <(find "${TARGET_LIBS[@]}" -name '*.dart' | sort)
mapfile -t ROUTE_FILES < <(find "${TARGET_LIBS[@]}" -name '*_routes.dart' | sort)

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
  # fontSize: <num>, (Border)Radius.circular(<num>), EdgeInsets.*(<num>),
  # Icons.<nome> (ícone Material cru — token exigido é AppIcons.<nome>;
  # padrão ancorado (^|[^A-Za-z])Icons\. para não acusar AppIcons.*).
  # Escape // gate4-ok libera a linha.
  # -------------------------------------------------------------------------
  while IFS=$'\t' read -r line content; do
    [ -z "${line:-}" ] && continue
    case "$content" in *"// gate4-ok"*) continue ;; esac
    emit "GATE4" "$f:$line" "$(printf '%s' "$content" | sed 's/^[[:space:]]*//')"
  done < <(grep -nE \
             'Color\(0x|\bColors\.[a-zA-Z]|fontSize: ?-?[0-9]|circular\( ?-?[0-9]|EdgeInsets\.(all|fromLTRB)\( ?-?[0-9]|EdgeInsets\.(symmetric|only)\([^)]*: ?-?[0-9]|(^|[^A-Za-z])Icons\.' "$f" \
             | grep -vE '\bColors\.(white|black|transparent)\b' \
             | sed -E 's/^([0-9]+):/\1\t/')
done

declare -A NAMED_WINDOWS
for f in "${ALL_DART[@]}"; do
  NAMED_WINDOWS["$f"]="$(grep -A4 -E '\.(go|push|replace)[A-Za-z]*Named\(' "$f" 2>/dev/null || true)"
done

route_used() {
  local class="$1" ident="$2" declfile="$3" f window
  for f in "${!NAMED_WINDOWS[@]}"; do
    window="${NAMED_WINDOWS[$f]}"
    [ -z "$window" ] && continue
    if printf '%s\n' "$window" | grep -qE "\\b${class}\\.${ident}\\b"; then
      return 0
    fi
    if [ "$f" = "$declfile" ] && printf '%s\n' "$window" | grep -qE "\\b${ident}\\b"; then
      return 0
    fi
  done
  return 1
}

for rf in "${ROUTE_FILES[@]}"; do
  class="$(grep -m1 -E 'class [A-Za-z0-9]+' "$rf" | sed -E 's/.*class ([A-Za-z0-9]+).*/\1/')"

  while IFS=$'\t' read -r line content; do
    [ -z "${line:-}" ] && continue
    case "$content" in *"// rota-sem-consumidor-ok"*) continue ;; esac
    ident="$(printf '%s' "$content" | sed -E 's/^[[:space:]]*static const ([A-Za-z0-9]+) = .*/\1/')"
    if ! route_used "$class" "$ident" "$rf"; then
      emit "ROTA" "$rf:$line" "$(printf '%s' "$content" | sed 's/^[[:space:]]*//')"
    fi
  done < <(grep -nE "^[[:space:]]*static const [A-Za-z0-9]*[Nn]ame = '[^']*';" "$rf" \
             | sed -E 's/^([0-9]+):/\1\t/')
done

echo ""
if [ "$fail" -ne 0 ]; then
  echo "✗ gates_guard: violação(ões) acima. Tokenize em app/lib/core/theme/, ligue a rota a um goNamed/pushNamed/replaceNamed real, ou justifique com // gateN-ok / // rota-sem-consumidor-ok: <motivo>."
  exit 1
fi
echo "✓ gates_guard: Gates 1 e 4 e a checagem de rota órfã limpos em ${TARGET_LIBS[*]}."
exit 0
