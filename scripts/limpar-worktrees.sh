#!/usr/bin/env bash
#
# Limpa os worktrees de agente acumulados em .claude/worktrees/, e as
# branches worktree-agent-* que eles deixam para trás. NUNCA toca worktree
# fora de .claude/worktrees/ (as sibling dirs do humano, tipo
# ../ganza-docsindex, ficam de fora por desenho: o filtro é o caminho).
#
# O que conta como "seguro para remover" (as duas condições, juntas):
#   1. LIMPO — `git status --porcelain` vazio dentro do worktree. Mudança
#      não commitada nunca é removida sem --force.
#   2. INTEGRADO — o HEAD do worktree é ancestral do HEAD atual do
#      worktree PRINCIPAL (checkout normal de $ROOT, não outro worktree).
#      Quando não é ancestral (caso comum: o conteúdo foi levado para a
#      branch principal por cherry-pick, e o hash do commit é outro), o
#      script cai para uma segunda checagem: pega o diff líquido de
#      merge-base..HEAD do worktree, lista os arquivos tocados, e compara
#      o blob de cada um contra o blob do MESMO caminho no HEAD atual do
#      worktree principal. Todo arquivo tem de bater byte a byte (ou estar
#      ausente dos dois lados, caso de deleção consistente); um arquivo só
#      divergir já classifica o worktree como "commit não integrado". Se o
#      diff líquido não tocar arquivo nenhum (commit vazio/no-op fora do
#      histórico principal), também conta como não integrado — sem arquivo
#      pra comparar não há prova de equivalência, e aqui a dúvida preserva.
#   A referência de integração é dinâmica — o HEAD do worktree principal
#   NO MOMENTO da execução, não origin/main nem origin/develop. Rodar o
#   script a partir de branches diferentes muda o que conta como
#   integrado; isso é intencional, não bug.
#
# Classificação e ação:
#   - limpo E integrado            -> remove o worktree (modo padrão já faz isso)
#   - sujo OU commit não integrado -> PRESERVA e relata caminho + motivo
#     (é trabalho que pode precisar virar PR — não se apaga sem decisão humana)
#
# Branch worktree-agent-<id>: removida só se casar exatamente o padrão
# `worktree-agent-*` E o worktree correspondente tiver sido removido (ou
# a branch estiver órfã — sem worktree nenhum apontando pra ela — e
# passar pela mesma checagem de integração). Branch com qualquer outro
# nome (feature/*, bugfix/*, ou nome custom que um agente tenha criado)
# NUNCA é tocada por este script, mesmo que o worktree que a segurava seja
# removido — fica pra decisão humana explícita.
#
# Flags:
#   --dry-run   só relata a classificação, não remove nada (worktree nem branch).
#   --force     remove também o que seria preservado (sujo e/ou não integrado).
#               Continua sem tocar branch fora do padrão worktree-agent-*.
#   Sem flag: modo padrão, remove só o que é seguro.
#
# Ao final: `git worktree prune` sempre roda. Sai 0 se nada ficou
# preservado (worktree limpo de verdade), sai 1 se algo foi preservado —
# serve de gate. Worktree que resiste à remoção (git worktree remove
# falha) é relatado e conta como preservado; o script não insiste com
# gambiarra de filesystem.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WORKTREES_DIR="$ROOT/.claude/worktrees"
BRANCH_GLOB='worktree-agent-*'

DRY_RUN=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    *)
      echo "uso: scripts/limpar-worktrees.sh [--dry-run] [--force]" >&2
      exit 2
      ;;
  esac
done

if [ ! -d "$WORKTREES_DIR" ]; then
  echo "✓ limpar-worktrees: $WORKTREES_DIR ainda não existe — nada a limpar."
  exit 0
fi

INTEGRATION_REF="$(git -C "$ROOT" rev-parse HEAD)"
preserved=0

is_integrated() {
  local commit="$1"
  git merge-base --is-ancestor "$commit" "$INTEGRATION_REF" 2>/dev/null && return 0

  local base
  base="$(git merge-base "$INTEGRATION_REF" "$commit" 2>/dev/null)" || return 1

  local f branch_hash main_hash checked=0
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    checked=1
    branch_hash="$(git rev-parse "${commit}:${f}" 2>/dev/null || true)"
    main_hash="$(git rev-parse "${INTEGRATION_REF}:${f}" 2>/dev/null || true)"
    if [ -z "$branch_hash" ] && [ -z "$main_hash" ]; then
      continue
    fi
    if [ "$branch_hash" != "$main_hash" ]; then
      return 1
    fi
  done < <(git diff --name-only "$base" "$commit")

  # Sem arquivo nenhum pra comparar (commit vazio/no-op não ancestral) não é
  # prova de equivalência — prefere preservar a assumir integração às cegas.
  [ "$checked" -eq 1 ] && return 0
  return 1
}

declare -a wt_paths=()
declare -a wt_branches=()
cur_path=""
cur_branch=""
while IFS= read -r line; do
  case "$line" in
    "worktree "*) cur_path="${line#worktree }" ;;
    "branch refs/heads/"*) cur_branch="${line#branch refs/heads/}" ;;
    "detached") cur_branch="" ;;
    "")
      if [ -n "$cur_path" ] && [[ "$cur_path" == "$WORKTREES_DIR"/* ]]; then
        wt_paths+=("$cur_path")
        wt_branches+=("$cur_branch")
      fi
      cur_path=""
      cur_branch=""
      ;;
  esac
done < <(git -C "$ROOT" worktree list --porcelain; echo)

echo "== worktrees em .claude/worktrees/ =="
for i in "${!wt_paths[@]}"; do
  path="${wt_paths[$i]}"
  branch="${wt_branches[$i]}"

  dirty=0
  [ -n "$(git -C "$path" status --porcelain=v1 2>/dev/null)" ] && dirty=1

  head_commit="$(git -C "$path" rev-parse HEAD 2>/dev/null || true)"
  integrated=0
  if [ -n "$head_commit" ] && is_integrated "$head_commit"; then
    integrated=1
  fi

  safe=0
  [ "$dirty" -eq 0 ] && [ "$integrated" -eq 1 ] && safe=1

  motivo=""
  [ "$dirty" -eq 1 ] && motivo="sujo"
  if [ "$integrated" -eq 0 ]; then
    motivo="${motivo:+$motivo; }commit não integrado em relação a $INTEGRATION_REF"
  fi

  if [ "$safe" -eq 1 ] || [ "$FORCE" -eq 1 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      if [ "$safe" -eq 1 ]; then
        echo "REMOVERIA  $path (limpo e integrado)"
      else
        echo "REMOVERIA --force  $path ($motivo)"
      fi
      continue
    fi
    git_force_flag=()
    [ "$safe" -eq 0 ] && git_force_flag=(--force)
    if err="$(git -C "$ROOT" worktree remove "${git_force_flag[@]}" "$path" 2>&1)"; then
      echo "removido   $path"
      if [[ "$branch" == worktree-agent-* ]]; then
        if git -C "$ROOT" branch -D "$branch" >/dev/null 2>&1; then
          echo "  branch removida: $branch"
        fi
      elif [ -n "$branch" ]; then
        echo "  branch preservada (fora do padrão worktree-agent-*): $branch"
      fi
    else
      echo "✗ resistiu à remoção: $path"
      echo "$err" | sed 's/^/    /'
      preserved=$((preserved + 1))
    fi
  else
    echo "✗ preservado: $path (branch: ${branch:-detached}) — $motivo"
    preserved=$((preserved + 1))
  fi
done

echo ""
echo "== branches worktree-agent-* órfãs (sem worktree associado) =="
found_orphan=0
while IFS= read -r br; do
  [ -z "$br" ] && continue
  in_use=0
  for b in "${wt_branches[@]}"; do
    [ "$b" = "$br" ] && in_use=1 && break
  done
  [ "$in_use" -eq 1 ] && continue
  found_orphan=1

  commit="$(git -C "$ROOT" rev-parse "$br" 2>/dev/null)" || continue
  if is_integrated "$commit" || [ "$FORCE" -eq 1 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "REMOVERIA branch órfã: $br"
    elif git -C "$ROOT" branch -D "$br" >/dev/null 2>&1; then
      echo "removida branch órfã: $br"
    else
      echo "✗ resistiu à remoção: branch $br"
      preserved=$((preserved + 1))
    fi
  else
    echo "✗ preservada branch órfã: $br (commit não integrado em relação a $INTEGRATION_REF — pode virar PR)"
    preserved=$((preserved + 1))
  fi
done < <(git -C "$ROOT" branch --list "$BRANCH_GLOB" | sed 's/^[* ]*//')
[ "$found_orphan" -eq 0 ] && echo "(nenhuma)"

[ "$DRY_RUN" -eq 0 ] && git -C "$ROOT" worktree prune

echo ""
if [ "$preserved" -gt 0 ]; then
  echo "✗ limpar-worktrees: $preserved worktree(s)/branch(es) preservados — revise acima."
  exit 1
fi
echo "✓ limpar-worktrees: nada preservado."
exit 0
