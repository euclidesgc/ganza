#!/usr/bin/env bash
#
# Recusa workflow com nome de job repetido.
#
# O `yaml.safe_load` do Python NÃO acusa chave duplicada — a última vence, em
# silêncio. O GitHub Actions, ao contrário, recusa o arquivo inteiro e o run
# falha SEM criar nenhum job, o que não deixa log para ler. Foi assim que um
# workflow quebrado chegou em develop.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falhou=0

for arquivo in "$RAIZ"/.github/workflows/*.yml "$RAIZ"/.github/workflows/*.yaml; do
  [ -f "$arquivo" ] || continue

  duplicados=$(grep -E '^  [a-zA-Z0-9_-]+:$' "$arquivo" | sort | uniq -d)
  if [ -n "$duplicados" ]; then
    echo "✗ $(basename "$arquivo"): job declarado mais de uma vez:"
    echo "$duplicados" | sed 's/^/    /'
    falhou=1
  fi

  if ! python3 -c "import yaml,sys; yaml.safe_load(open('$arquivo'))" 2>/dev/null; then
    echo "✗ $(basename "$arquivo"): YAML inválido"
    falhou=1
  fi
done

[ "$falhou" -ne 0 ] && exit 1
echo "✓ workflows: sem job duplicado e YAML válido"
exit 0
