#!/usr/bin/env bash
#
# Recusa workflow inválido antes do push. Três verificações, cada uma nascida
# de um erro real que chegou em develop:
#
#   1. Job declarado duas vezes. O `yaml.safe_load` do Python NÃO acusa — a
#      última chave vence, em silêncio. O GitHub recusa o arquivo inteiro e o
#      run falha SEM criar job, o que não deixa log para ler.
#   2. YAML inválido.
#   3. Sintaxe de shell quebrada nos blocos `run:`. Uma aspa perdida numa
#      edição por substituição só aparece no runner, minutos depois.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falhou=0

for arquivo in "$RAIZ"/.github/workflows/*.yml "$RAIZ"/.github/workflows/*.yaml; do
  [ -f "$arquivo" ] || continue
  nome=$(basename "$arquivo")

  duplicados=$(grep -E '^  [a-zA-Z0-9_-]+:$' "$arquivo" | sort | uniq -d)
  if [ -n "$duplicados" ]; then
    echo "✗ $nome: job declarado mais de uma vez:"
    echo "$duplicados" | sed 's/^/    /'
    falhou=1
  fi

  if ! python3 -c "import yaml; yaml.safe_load(open('$arquivo'))" 2>/dev/null; then
    echo "✗ $nome: YAML inválido"
    falhou=1
    continue
  fi

  saida=$(python3 - "$arquivo" <<'PY'
import subprocess, sys, yaml

arquivo = sys.argv[1]
doc = yaml.safe_load(open(arquivo))
problemas = []

for nome_job, job in (doc.get('jobs') or {}).items():
    for passo in job.get('steps') or []:
        script = passo.get('run')
        if not script:
            continue
        r = subprocess.run(['bash', '-n'], input=script, text=True, capture_output=True)
        if r.returncode != 0:
            rotulo = passo.get('name') or '(sem nome)'
            problemas.append(f"    {nome_job} → {rotulo}: {r.stderr.strip().splitlines()[-1]}")

print('\n'.join(problemas))
PY
)
  if [ -n "$saida" ]; then
    echo "✗ $nome: shell inválido em passo(s) run:"
    echo "$saida"
    falhou=1
  fi
done

[ "$falhou" -ne 0 ] && exit 1
echo "✓ workflows: sem job duplicado, YAML válido e shell dos passos íntegro"
exit 0
