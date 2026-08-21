#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROADMAP="$ROOT/docs/roadmap.md"
fail=0

error() {
  printf '✗ gauntlet: %s\n' "$*" >&2
  fail=1
}

criterios_changes=('Planejado originalmente' 'Por que não foi possível prosseguir' 'Alternativas consideradas' 'Decisão tomada' 'Resumo da resolução' 'Reconciliação documental')

verificar_blocos_changes() {
  local arquivo="${1}" prefixo="${2}"
  while IFS=: read -r start _; do
    next="$(awk -v start="$start" 'NR > start && /^### / { print NR; exit }' "$arquivo")"
    if [ -n "$next" ]; then
      block="$(sed -n "${start},$((next - 1))p" "$arquivo")"
    else
      block="$(sed -n "${start},\$p" "$arquivo")"
    fi
    for criterion in "${criterios_changes[@]}"; do
      grep -q "$criterion" <<<"$block" || error "$prefixo: mudança em changes.md sem '$criterion'"
    done
  done < <(grep -nE '^### CHG-[0-9]{3} ' "$arquivo" || true)
}

if [ "${1:-}" = '--changes' ]; then
  changes_file="${2:-}"
  [ -n "$changes_file" ] || { error '--changes exige o caminho de um changes.md'; exit 1; }
  [ -f "$changes_file" ] || { error "$changes_file: arquivo ausente"; exit 1; }
  verificar_blocos_changes "$changes_file" "$changes_file"
  if [ "$fail" -ne 0 ]; then
    exit 1
  fi
  echo '✓ gauntlet --changes: blocos CHG íntegros'
  exit 0
fi

[ -f "$ROADMAP" ] || { error 'docs/roadmap.md ausente'; exit 1; }

while read -r id; do
  matches=("$ROOT"/docs/"$id"_*)
  if [ ${#matches[@]} -ne 1 ] || [ ! -d "${matches[0]}" ]; then
    error "item $id precisa de uma pasta docs/${id}_descricao"
    continue
  fi

  feature="${matches[0]}"
  for file in 01_prd.md 02_specs.md 03_plan.md decisions.md changes.md; do
    [ -f "$feature/$file" ] || error "$id: $file ausente"
  done
  [ -f "$feature/03_plan.md" ] || continue

  grep -q '^## Gauntlet$' "$feature/03_plan.md" || error "$id: seção Gauntlet ausente"
  for criterion in 'Referência' 'Rubrica binária' 'Invariantes bloqueantes' 'Provas' 'Limites' 'Evidência E2E'; do
    grep -q "$criterion" "$feature/03_plan.md" || error "$id: Gauntlet sem '$criterion'"
  done

  grep -q '^# Decisões da feature' "$feature/decisions.md" || error "$id: decisions.md sem título canônico"
  grep -q '^## Modelo de decisão$' "$feature/decisions.md" || error "$id: decisions.md sem modelo"

  grep -q '^# Histórico de mudanças' "$feature/changes.md" || error "$id: changes.md sem título canônico"
  grep -q '^## Modelo de registro$' "$feature/changes.md" || error "$id: changes.md sem modelo"
  for criterion in "${criterios_changes[@]}"; do
    grep -q "$criterion" "$feature/changes.md" || error "$id: changes.md sem '$criterion'"
  done

  verificar_blocos_changes "$feature/changes.md" "$id"

  if [ -d "$feature/e2e" ]; then
    while read -r round; do
      report="$round/report.md"
      [ -f "$report" ] || { error "$id: $(basename "$round") sem report.md"; continue; }

      grep -q '^# Round ' "$report" || error "$id: $(basename "$round") report.md sem título de rodada"
      grep -q '^|' "$report" || error "$id: $(basename "$round") report.md sem tabela de passos"

      if ! grep -q 'Rodada histórica' "$report"; then
        grep -q '^## Contexto$' "$report" || error "$id: $(basename "$round") report.md sem contexto"
        grep -q '^## Passos executados$' "$report" || error "$id: $(basename "$round") report.md sem passos"
        grep -q '^## Ambiente e comandos$' "$report" || error "$id: $(basename "$round") report.md sem ambiente e comandos"
      fi

      while IFS= read -r reference; do
        [ -n "$reference" ] || continue
        case "$reference" in
          http://*|https://*|mailto:*|'#'*) continue ;;
          /*|*'..'*) error "$id: $(basename "$round") referência inválida: $reference" ;;
          *) [ -e "$round/$reference" ] || error "$id: $(basename "$round") evidência referenciada ausente: $reference" ;;
        esac
      done < <(grep -oE '\]\([^)]+\)' "$report" | sed -E 's/^\]\(//; s/\)$//' || true)

      evidence_count=0
      while IFS= read -r evidence; do
        [ -n "$evidence" ] || continue
        evidence_count=$((evidence_count + 1))
        [ -f "$round/$evidence" ] || error "$id: $(basename "$round") PNG referenciado ausente: $evidence"
      done < <(grep -oE '\]\([^)]+\.png\)' "$report" | sed -E 's/^\]\(//; s/\)$//' || true)
      [ "$evidence_count" -gt 0 ] || error "$id: $(basename "$round") report.md sem PNG referenciado"
    done < <(find "$feature/e2e" -mindepth 1 -maxdepth 1 -type d -name 'round_[0-9][0-9]' | sort)
  fi
done < <(sed -nE 's/^[[:space:]]*-?[[:space:]]*\[[x-]\][[:space:]]+([0-9]{3})[[:space:]].*/\1/p' "$ROADMAP")

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo '✓ gauntlet: roadmap, documentos e contratos canônicos íntegros'
