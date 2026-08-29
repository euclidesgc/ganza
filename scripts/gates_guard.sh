#!/usr/bin/env bash
#
# Guard-script dos Gates de qualidade (rede de segurança automática do CI).
# bash + grep + awk, ZERO dependência Dart — cobre o que é mecanicamente
# detectável dos Gates 1 e 4, mais a checagem de rota nomeada órfã. Os
# Gates 2 e 3 (tier de widget, arquivo gordo) são heurísticos demais para
# grep confiável e ficam no gate de revisão.
#
# Gate 4 cobre também Icons.<nome> cru (ícone deve vir de AppIcons em
# core/theme/). Padrão ancorado (^|[^A-Za-z])Icons\. para não acusar
# AppIcons.<nome>, que é o token exigido.
#
# GOLDEN SEM RELÓGIO — nenhum app/test/**/*_golden_test.dart lê o relógio
# (DateTime.now/timestamp, clock.now): golden compara pixels, e fixture
# relativa a "hoje" faz a imagem mudar de texto a cada dia. Escape na própria
# linha: // golden-relogio-ok: <motivo>.
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
# confundir `name` de uma rota com `name` de outra. Um awk junta a
# declaração com a linha seguinte quando o `dart format` a quebra em
# `static const fooName =` + `'valor';` por passar de 80 colunas — sem
# isso o formatador apagaria a checagem sem tocar em nenhum escape.
#
# FUNÇÃO ÓRFÃ — toda pasta de primeiro nível em supabase/functions/ (exceto
# main, _shared e health) precisa aparecer em app/lib ou em
# supabase/migrations; senão é Edge Function alcançável por HTTP e sem
# nenhum chamador (D38 — o caso real foi conciliate e import-ofx, prontas e
# testadas, mas sem tela nem job que as invoque). Escape:
# // funcao-sem-consumidor-ok: <motivo> em qualquer arquivo da própria
# pasta da função, para função chamada só por outra função ou por
# agendador externo.
#
# Sai 0 se limpo, 1 se achar violação. Plugado no .github/workflows/ci.yml.
#
# Escapes pontuais (com justificativa):
#   // gate1-ok: <motivo>                 — na própria linha da violação.
#   // gate4-ok: <motivo>                 — na própria linha do literal
#     OU em qualquer linha entre ela e o fim do statement (até 9 linhas
#     à frente, parando na primeira com `;`): o `dart format` pode
#     quebrar uma chamada longa em várias linhas e empurrar o comentário
#     para a linha de fechamento (`);`), separado do literal acusado —
#     as duas formas valem, gate4_escaped() cobre ambas.
#   // rota-sem-consumidor-ok: <motivo>   — aceito em DUAS posições: em
#     comentário de linha PRÓPRIA (até 3 linhas) ACIMA da declaração
#     `static const ...Name = '...';`, ou ao final dela, na mesma linha
#     (como os outros dois escapes). Prefira a linha própria acima: um
#     `dart format` limpo (exigido pelo DoD) mantém a declaração curta e
#     o escape longe do risco de a linha crescer e o comentário ser
#     empurrado pelo wrap — mas a forma de fim de linha também é
#     verificada, para não quebrar em silêncio quem já a usa. Só para
#     rota alcançada apenas por redirect da guarda de rota, nunca por
#     toque — ex.: a rota raiz, que só é atingida pelo initialLocation e
#     pelo fallback do redirect.
#
#   // funcao-sem-consumidor-ok: <motivo> — em qualquer arquivo dentro de
#     supabase/functions/<nome>/, para a função inteira (não há linha
#     única representativa de "a função existe" como há para uma
#     declaração de rota).
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
#   - supabase/functions/main/    é o roteador que despacha por nome de
#                                  pasta — não é, ele mesmo, uma função
#                                  chamável por nome.
#   - supabase/functions/_shared/ é biblioteca importada pelas funções,
#                                  sem handler nem rota própria.
#   - supabase/functions/health/  sonda de infraestrutura chamada pelo
#                                  orquestrador (Coolify), não pelo app nem
#                                  por pg_cron — por desenho nunca vai
#                                  aparecer em app/lib nem em migrations.

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

gate4_escaped() { # <file> <line-do-literal-acusado>
  local f="$1" from="$2" cur cap i
  cap=$((from + 9))
  for ((i = from; i <= cap; i++)); do
    cur="$(sed -n "${i}p" "$f")"
    [ -z "$cur" ] && break
    case "$cur" in *"// gate4-ok"*) return 0 ;; esac
    case "$cur" in *";"*) break ;; esac
  done
  return 1
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
  # Escape // gate4-ok libera o CONSTRUTO, não só a linha física: o
  # `dart format` pode quebrar uma chamada longa em várias linhas e
  # empurrar o comentário para a linha de fechamento (`);`), separado do
  # literal acusado — gate4_escaped busca `// gate4-ok` da linha
  # acusada até a primeira linha com `;` logo à frente (teto de 9
  # linhas), então tanto `literal); // gate4-ok` quanto o comentário na
  # linha do fechamento após o wrap continuam valendo.
  # -------------------------------------------------------------------------
  while IFS=$'\t' read -r line content; do
    [ -z "${line:-}" ] && continue
    gate4_escaped "$f" "$line" && continue
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

# dart format quebra `static const fooName =` e o valor em duas linhas
# quando a declaração passa de 80 colunas — o awk junta essas duas linhas
# numa só antes do grep, senão o formatador cega a checagem sem tocar o
# escape. O escape mora numa linha de comentário PRÓPRIA acima da
# declaração (não ao final da linha) por isso: comentário de fim de linha
# empurra a declaração para além de 80 colunas e vira alvo do wrap.
for rf in "${ROUTE_FILES[@]}"; do
  class="$(grep -m1 -E 'class [A-Za-z0-9]+' "$rf" | sed -E 's/.*class ([A-Za-z0-9]+).*/\1/')"

  while IFS=$'\t' read -r startline joined; do
    [ -z "${startline:-}" ] && continue
    ident="$(printf '%s' "$joined" | sed -E 's/^[[:space:]]*static const ([A-Za-z0-9]+).*/\1/')"

    lookback_from=$((startline - 3))
    [ "$lookback_from" -lt 1 ] && lookback_from=1
    lookback_to=$((startline - 1))
    escaped=0
    if [ "$lookback_to" -ge "$lookback_from" ] \
      && sed -n "${lookback_from},${lookback_to}p" "$rf" | grep -q '// rota-sem-consumidor-ok'; then
      escaped=1
    fi
    case "$joined" in *"// rota-sem-consumidor-ok"*) escaped=1 ;; esac
    [ "$escaped" -eq 1 ] && continue

    if ! route_used "$class" "$ident" "$rf"; then
      emit "ROTA" "$rf:$startline" \
        "$(printf '%s' "$joined" | sed -E 's/^[[:space:]]*//; s/[[:space:]]+/ /g')"
    fi
  done < <(awk '
    pending {
      print startline "\t" firstline " " $0
      pending = 0
      next
    }
    /^[[:space:]]*static const [A-Za-z0-9]*[Nn]ame[[:space:]]*=[[:space:]]*$/ {
      pending = 1
      startline = NR
      firstline = $0
      next
    }
    /^[[:space:]]*static const [A-Za-z0-9]*[Nn]ame[[:space:]]*=.*;/ {
      print NR "\t" $0
    }
  ' "$rf")
done

# FUNÇÃO ÓRFÃ — Edge Function alcançável por HTTP (o roteador de
# supabase/functions/main despacha por nome de pasta, sem allowlist) e sem
# nenhum consumidor: nem tela do app nem migration/pg_cron a chamam. É o
# análogo de backend da checagem de rota órfã acima (D38).
if [ -d "supabase/functions" ]; then
  mapfile -t FUNCTION_DIRS < <(find supabase/functions -mindepth 1 -maxdepth 1 -type d \
    ! -name main ! -name _shared ! -name health | sort)
  for fd in "${FUNCTION_DIRS[@]}"; do
    fname="$(basename "$fd")"
    if grep -rq -- "$fname" app/lib supabase/migrations 2>/dev/null; then
      continue
    fi
    if grep -rq -- '// funcao-sem-consumidor-ok' "$fd" 2>/dev/null; then
      continue
    fi
    emit "FUNCAO" "$fd" "sem referência em app/lib nem em supabase/migrations"
  done
fi

# GOLDEN SEM RELÓGIO — golden compara pixels e a tela imprime datas: fixture
# derivada de DateTime.now() muda o texto renderizado a cada dia e quebra a
# imagem sozinha, sem ninguém ter tocado no app. É o que derrubou os dois
# goldens do card de ocorrência — o mestre trazia "24/08, segunda" e o teste
# passou a desenhar "26/08, quarta". Fixture de golden é data fixa e distante
# o bastante para que vencida/futura valham em qualquer dia de execução.
# Escape: // golden-relogio-ok: <motivo> na própria linha.
if [ -d "app/test" ]; then
  mapfile -t GOLDEN_TESTS < <(find app/test -name '*_golden_test.dart' | sort)
  for f in "${GOLDEN_TESTS[@]}"; do
    while IFS=$'\t' read -r line content; do
      [ -z "${line:-}" ] && continue
      case "$content" in *"// golden-relogio-ok"*) continue ;; esac
      emit "GOLDEN" "$f:$line" "$(printf '%s' "$content" | sed 's/^[[:space:]]*//')"
    done < <(grep -nE 'DateTime\.(now|timestamp)\(\)|clock\.now\(\)' "$f" \
               | sed -E 's/^([0-9]+):/\1\t/')
  done
fi

echo ""
if [ "$fail" -ne 0 ]; then
  echo "✗ gates_guard: violação(ões) acima. Tokenize em app/lib/core/theme/, ligue a rota a um goNamed/pushNamed/replaceNamed real, dê um consumidor à Edge Function, troque a fixture de golden por data fixa, ou justifique com // gateN-ok / // rota-sem-consumidor-ok / // funcao-sem-consumidor-ok / // golden-relogio-ok: <motivo>."
  exit 1
fi
echo "✓ gates_guard: Gates 1 e 4, as checagens de rota órfã e de função órfã, e os goldens sem relógio limpos em ${TARGET_LIBS[*]}, supabase/functions e app/test."
exit 0
