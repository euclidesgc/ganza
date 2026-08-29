#!/usr/bin/env bash
#
# lint-dod.sh — caça, por máquina, os defeitos de critério de DoD que já
# custaram rodadas inteiras de correção (ver docs/002_conta_e_configuracoes/
# changes.md, CHG-019 a CHG-041). Dois modos:
#
#   scripts/lint-dod.sh <plano.md>                       Tier A — estático
#   scripts/lint-dod.sh --run <plano.md> <ID-da-tarefa>   Tier B — executivo
#
# Tier A varre os blocos "**DoD da tarefa**" de um 03_plan.md e aponta
# linha por linha as classes de defeito conhecidas (A1, A2, A4, A5, A6, A7,
# A8, A9, A11, A12, A13). Sai 0 se limpo, != 0 se achar algo.
#
# Tier B extrai cada span entre crases do bloco de UMA tarefa e roda cada um
# na árvore atual, imprimindo comando/código de saída/linhas de saída — sem
# julgar. Pula, com aviso, spans que casam A11 (muta o Docker compartilhado)
# ou A7 (expõe segredo em argv).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TOTAL=0

usage() {
  cat <<'EOF'
uso:
  scripts/lint-dod.sh <plano.md>
  scripts/lint-dod.sh --run <plano.md> <ID-da-tarefa>
EOF
}

# ---------------------------------------------------------------------------
# Mensagens
# ---------------------------------------------------------------------------

MSG_A1='sem `cd app` no span: da raiz, `flutter analyze` completa em 2 ms sempre `0` e `flutter test` falha com `Test directory "test" not found`.'
MSG_A2='`dart format` sem `--output=none` muta a árvore que a linha deveria só medir.'
MSG_A4='`psql` sem `docker compose` nem `-h`/`PGHOST` não alcança o Postgres do ganza (infra/local/docker-compose.yml, porta 54322) — procura o socket default e nunca conecta.'
MSG_A5='`grep -r` sobre diretório alcança `.env` ignorado e pastas de build; troque por `git grep`, que só enxerga arquivo versionado.'
MSG_A6='`git diff` sem base fixa (`merge-base`, `origin/`, `HEAD~` ou `..`) sai vazio hoje e continua vazio depois do commit, aprovando por ausência.'
MSG_A7='`curl` no mesmo span que uma variável de segredo expande o valor no argv, visível em `ps aux` para qualquer usuário da máquina.'
MSG_A8='caminho ignorado pelo git citado sem comando de bootstrap na mesma linha — não existe em worktree recém-criado.'
MSG_A9='o padrão deste grep casa o próprio arquivo de plano, e o alvo inclui `docs/` ou a raiz — o critério casa a si mesmo.'
MSG_A11='muta o projeto Docker (`ganza-local`), que é único e compartilhado pelos worktrees.'
MSG_A12='SQL de prova com INSERT/UPDATE/DELETE sem ROLLBACK no mesmo bloco deixa dado plantado para trás.'
MSG_A13='"exatamente N" sem N caminhos entre crases na mesma linha — contagem não reproduzível por quem lê depois.'

report() {
  local planfile="$1" lineno="$2" rule="$3" msg="$4" span="$5"
  printf '%s:%s: [%s] %s :: `%s`\n' "$planfile" "$lineno" "$rule" "$msg" "$span"
  TOTAL=$((TOTAL + 1))
}

# ---------------------------------------------------------------------------
# Extração de blocos "DoD da tarefa" e de spans entre crases
# ---------------------------------------------------------------------------

extract_dod_lines() {
  local planfile="$1"
  # 007_agenda em diante abandonou o cabeçalho "**DoD da tarefa**": os bullets
  # do critério seguem direto da linha da tarefa. O estado "aguardando" cobre
  # as duas convenções sem duplicar a extração por plano.
  awk '
    BEGIN { taskid = ""; indod = 0; aguardando = 0 }
    {
      line = $0
      if (line ~ /^- \[[ xX]\][[:space:]]+\*\*T[0-9]+\.[0-9]+\*\*/) {
        match(line, /\*\*T[0-9]+\.[0-9]+\*\*/)
        taskid = substr(line, RSTART + 2, RLENGTH - 4)
        indod = 0
        aguardando = 1
        next
      }
      if (aguardando) {
        if (line ~ /^[[:space:]]*$/) {
          next
        }
        if (line ~ /^[[:space:]]*\*\*DoD da tarefa\*\*[[:space:]]*$/) {
          indod = 1
          aguardando = 0
          next
        }
        if (line ~ /^[[:space:]]+-[[:space:]]/) {
          indod = 1
          aguardando = 0
        } else {
          aguardando = 0
          next
        }
      }
      if (indod) {
        if (line ~ /^[[:space:]]+-[[:space:]]/) {
          print NR "\x1f" taskid "\x1f" line
        } else {
          indod = 0
        }
      }
    }
  ' "$planfile"
}

extract_spans() {
  awk -v line="$1" 'BEGIN {
    n = split(line, p, "`")
    for (i = 2; i <= n; i += 2) print p[i]
  }'
}

is_pathlike() {
  local s="$1"
  [[ "$s" == */* ]] && return 0
  [[ "$s" =~ \.[A-Za-z0-9]+$ ]] && return 0
  return 1
}

looks_like_bare_path() {
  local s="$1"
  [[ "$s" =~ ^[A-Za-z0-9_./-]+$ ]] || return 1
  [[ "$s" == */* ]] || return 1
  return 0
}

word_to_num() {
  local w="${1,,}"
  case "$w" in
    um | uma) echo 1 ;;
    dois | duas) echo 2 ;;
    três | tres) echo 3 ;;
    quatro) echo 4 ;;
    cinco) echo 5 ;;
    seis) echo 6 ;;
    sete) echo 7 ;;
    oito) echo 8 ;;
    nove) echo 9 ;;
    dez) echo 10 ;;
    *)
      if [[ "$w" =~ ^[0-9]+$ ]]; then
        echo "$w"
      else
        echo ""
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Regras (uma função por regra; span/linha entra, "0" == achado, "1" == limpo)
# ---------------------------------------------------------------------------

rule_a1() {
  local s="$1"
  local hit
  hit=$(awk -v s="$s" '
    BEGIN {
      n = split(s, segs, /(&&|;)/)
      out = 0
      for (i = 1; i <= n; i++) {
        seg = segs[i]
        gsub(/^[ \t]+/, "", seg)
        gsub(/[ \t]+$/, "", seg)
        m = split(seg, words, /[ \t]+/)
        if (m >= 1 && (words[1] == "flutter" || words[1] == "dart")) {
          if (seg ~ /(^|[^A-Za-z])(analyze|test|format|pub|run)([^A-Za-z]|$)/) {
            out = 1
          }
        }
      }
      print out
    }
  ')
  [[ "$hit" == "1" ]] || return 1
  [[ "$s" == *"cd app"* ]] && return 1
  return 0
}

rule_a2() {
  local s="$1"
  [[ "$s" =~ dart[[:space:]]+format ]] || return 1
  [[ "$s" == *"--output=none"* ]] && return 1
  return 0
}

rule_a4() {
  local s="$1"
  local hit
  hit=$(awk -v s="$s" '
    BEGIN {
      n = split(s, segs, /(&&|;|\|)/)
      out = 0
      for (i = 1; i <= n; i++) {
        seg = segs[i]
        gsub(/^[ \t]+/, "", seg)
        gsub(/[ \t]+$/, "", seg)
        split(seg, words, /[ \t]+/)
        if (words[1] == "psql") out = 1
      }
      print out
    }
  ')
  [[ "$hit" == "1" ]] || return 1
  [[ "$s" == *"docker compose"* ]] && return 1
  [[ "$s" == *"-h "* ]] && return 1
  [[ "$s" == *"PGHOST"* ]] && return 1
  return 0
}

rule_a5() {
  local s="$1"
  [[ "$s" =~ grep[[:space:]]+-[A-Za-z]*r[A-Za-z]* ]] || return 1
  local rest="$s"
  local targets=""
  if [[ "$rest" == *\'*\'* ]]; then
    targets="${rest##*\'}"
  elif [[ "$rest" == *\"*\"* ]]; then
    targets="${rest##*\"}"
  else
    targets="${rest#*grep }"
    targets="${targets#* }"
    targets="${targets#* }"
  fi
  targets="${targets#"${targets%%[![:space:]]*}"}"
  targets="${targets%"${targets##*[![:space:]]}"}"
  if [[ -z "$targets" ]]; then
    return 0
  fi
  local t base
  for t in $targets; do
    base="${t##*/}"
    if [[ "$base" != *.* ]]; then
      return 0
    fi
  done
  return 1
}

rule_a6() {
  local s="$1"
  [[ "$s" == *"git diff"* ]] || return 1
  [[ "$s" == *"merge-base"* ]] && return 1
  [[ "$s" == *"origin/"* ]] && return 1
  [[ "$s" == *"HEAD~"* ]] && return 1
  [[ "$s" == *".."* ]] && return 1
  return 0
}

rule_a7() {
  local s="$1"
  [[ "$s" == *curl* ]] || return 1
  [[ "$s" =~ \$\{?[A-Za-z0-9_]*(SECRET|PASSWORD|SERVICE_ROLE|TOKEN)[A-Za-z0-9_]*\}? ]] || return 1
  return 0
}

rule_a9() {
  local planfile="$1" s="$2"
  [[ "$s" == *grep* ]] || return 1
  local pattern="" targets=""
  if [[ "$s" == *\'* ]]; then
    pattern="${s#*\'}"
    pattern="${pattern%%\'*}"
    targets="${s##*\'}"
  elif [[ "$s" == *\"* ]]; then
    pattern="${s#*\"}"
    pattern="${pattern%%\"*}"
    targets="${s##*\"}"
  else
    return 1
  fi
  [[ -z "$pattern" ]] && return 1

  local trimmed="${targets//[[:space:]]/}"
  local hits_plan=0
  if [[ -z "$trimmed" ]]; then
    [[ "$s" =~ grep[[:space:]]+-[A-Za-z]*r[A-Za-z]* ]] && hits_plan=1
  else
    local t dirtoken
    for t in $targets; do
      if [[ "$t" == "$planfile" || "$t" == "." || "$t" == "./" ]]; then
        hits_plan=1
      else
        dirtoken="${t%/}/"
        [[ "$planfile" == "$dirtoken"* ]] && hits_plan=1
      fi
    done
  fi
  [[ "$hits_plan" -eq 1 ]] || return 1

  grep -qE -- "$pattern" "$planfile" 2>/dev/null || return 1
  return 0
}

rule_a11() {
  local s="$1"
  local hit
  hit=$(awk -v s="$s" '
    BEGIN {
      n = split(s, words, /[ \t]+/)
      compose = 0
      out = 0
      for (i = 1; i <= n; i++) {
        w = words[i]
        gsub(/^[^A-Za-z0-9]+|[^A-Za-z0-9]+$/, "", w)
        if (w == "compose") { compose = 1 }
        if (compose && (w == "down" || w == "rm" || w == "stop" || w == "restart")) { out = 1 }
        if (w == "volume" && words[i + 1] != "") {
          nextw = words[i + 1]
          gsub(/^[^A-Za-z0-9]+|[^A-Za-z0-9]+$/, "", nextw)
          if (nextw == "rm") { out = 1 }
        }
      }
      print out
    }
  ')
  [[ "$hit" == "1" ]] && return 0
  if [[ "$s" == *"infra/local/docker-compose.yml"* ]]; then
    [[ "$s" =~ (sed[[:space:]]+-i|\>\>?[[:space:]]|Write|Edit) ]] && return 0
  fi
  return 1
}

rule_a13_line() {
  local text="$1"
  [[ "$text" =~ [Ee]xatamente[[:space:]]+([A-Za-zÀ-ÖØ-öø-ÿ]+|[0-9]+) ]] || return 1
  local word="${BASH_REMATCH[1]}"
  local n
  n=$(word_to_num "$word")
  [[ -z "$n" ]] && return 1
  local count=0 span
  while IFS= read -r span; do
    [[ -z "$span" ]] && continue
    if is_pathlike "$span"; then
      count=$((count + 1))
    fi
  done < <(extract_spans "$text")
  [[ "$count" -ne "$n" ]] && return 0
  return 1
}

rule_a8() {
  local text="$1" span="$2"
  looks_like_bare_path "$span" || return 1
  git -C "$ROOT" check-ignore -q -- "$span" 2>/dev/null || return 1
  if echo "$text" | grep -qE 'scripts/[A-Za-z0-9_-]+\.sh'; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Tier A — varredura estática
# ---------------------------------------------------------------------------

lint_static() {
  local planfile="$1"
  local -A block_text
  local -A block_dml_line
  local lineno taskid text span

  while IFS=$'\x1f' read -r lineno taskid text; do
    block_text["$taskid"]="${block_text[$taskid]:-}${text}"$'\n'

    if [[ -z "${block_dml_line[$taskid]:-}" ]]; then
      if echo "$text" | grep -qiE '(insert[[:space:]]+into|update[[:space:]]+[A-Za-z_.]+[[:space:]]+set|delete[[:space:]]+from)'; then
        block_dml_line["$taskid"]="$lineno"
      fi
    fi

    while IFS= read -r span; do
      [[ -z "$span" ]] && continue

      if rule_a1 "$span"; then
        report "$planfile" "$lineno" "A1" "$MSG_A1" "$span"
      fi
      if rule_a2 "$span"; then
        report "$planfile" "$lineno" "A2" "$MSG_A2" "$span"
      fi
      if rule_a4 "$span"; then
        report "$planfile" "$lineno" "A4" "$MSG_A4" "$span"
      fi
      if rule_a5 "$span"; then
        report "$planfile" "$lineno" "A5" "$MSG_A5" "$span"
      fi
      if rule_a6 "$span"; then
        report "$planfile" "$lineno" "A6" "$MSG_A6" "$span"
      fi
      if rule_a7 "$span"; then
        report "$planfile" "$lineno" "A7" "$MSG_A7" "$span"
      fi
      if rule_a9 "$planfile" "$span"; then
        report "$planfile" "$lineno" "A9" "$MSG_A9" "$span"
      fi
      if rule_a11 "$span"; then
        report "$planfile" "$lineno" "A11" "$MSG_A11" "$span"
      fi
      if rule_a8 "$text" "$span"; then
        report "$planfile" "$lineno" "A8" "$MSG_A8" "$span"
      fi
    done < <(extract_spans "$text")

    if rule_a13_line "$text"; then
      report "$planfile" "$lineno" "A13" "$MSG_A13" "$text"
    fi
  done < <(extract_dod_lines "$planfile")

  for taskid in "${!block_dml_line[@]}"; do
    local blocktext="${block_text[$taskid]:-}"
    if ! printf '%s' "$blocktext" | grep -qi 'rollback'; then
      report "$planfile" "${block_dml_line[$taskid]}" "A12" "$MSG_A12" "(bloco da tarefa $taskid)"
    fi
  done

  return 0
}

# ---------------------------------------------------------------------------
# Tier B — modo executivo
# ---------------------------------------------------------------------------

run_mode() {
  local planfile="$1" wanttask="$2"
  local lineno taskid text span
  local -a spans=()

  while IFS=$'\x1f' read -r lineno taskid text; do
    [[ "$taskid" == "$wanttask" ]] || continue
    while IFS= read -r span; do
      [[ -z "$span" ]] && continue
      spans+=("$span")
    done < <(extract_spans "$text")
  done < <(extract_dod_lines "$planfile")

  if [[ ${#spans[@]} -eq 0 ]]; then
    echo "Nenhum span encontrado para a tarefa '$wanttask' em $planfile" >&2
    return 1
  fi

  local out code lines
  for span in "${spans[@]}"; do
    if rule_a11 "$span"; then
      printf 'PULADO (A11: muta ambiente compartilhado) :: `%s`\n' "$span"
      continue
    fi
    if rule_a7 "$span"; then
      printf 'PULADO (A7: segredo em argv) :: `%s`\n' "$span"
      continue
    fi
    out="$(cd "$ROOT" && timeout 15 bash -c "$span" 2>&1)"
    code=$?
    if [[ -z "$out" ]]; then
      lines=0
    else
      lines=$(printf '%s\n' "$out" | wc -l)
    fi
    printf 'COMANDO: %s\nEXIT: %s\nLINHAS: %s\n---\n' "$span" "$code" "$lines"
  done
  return 0
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
  if [[ "${1:-}" == "--run" ]]; then
    if [[ $# -ne 3 ]]; then
      usage >&2
      exit 2
    fi
    run_mode "$2" "$3"
    exit $?
  fi

  if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
  fi

  if [[ ! -f "$1" ]]; then
    echo "arquivo não encontrado: $1" >&2
    exit 2
  fi

  lint_static "$1"

  if [[ "$TOTAL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
