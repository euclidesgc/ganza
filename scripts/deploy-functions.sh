#!/usr/bin/env bash
#
# Publica as Edge Functions no Supabase self-hosted.
#
# No self-hosted não existe `supabase functions deploy`: o edge-runtime serve
# o que estiver no volume `volumes/functions` do serviço. Publicar é sincronizar
# esse diretório e reiniciar o runtime — é o que este script faz.
#
# Usa `tar` sobre ssh em vez de rsync porque o servidor não tem rsync, e
# instalar dependência numa máquina compartilhada com outros dois projetos
# custa mais do que a alternativa.
#
# Uso:  scripts/deploy-functions.sh [--dry-run]

set -euo pipefail

HOST="${GANZA_HOST:-64.181.165.16}"
SERVICO="${GANZA_SUPABASE_UUID:-lqsjrqqs6r8rnggbvwpi4nuf}"
URL_PUBLICA="${GANZA_SUPABASE_URL:-https://supabase.ganza.bmjtech.duckdns.org}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORIGEM="$RAIZ/supabase/functions"

# O destino é montado a partir de duas variáveis; um valor vazio aqui viraria
# `rm -rf /*` no servidor. A guarda é barata e o erro seria irreversível.
if [ -z "$SERVICO" ] || [ ${#SERVICO} -lt 8 ]; then
  echo "✗ GANZA_SUPABASE_UUID inválido — abortando antes de tocar no servidor." >&2
  exit 1
fi
DESTINO="/data/coolify/services/$SERVICO/volumes/functions"

[ -d "$ORIGEM/main" ] || { echo "✗ $ORIGEM/main não existe — o runtime não sobe sem o serviço principal." >&2; exit 1; }

FUNCOES="$(find "$ORIGEM" -maxdepth 1 -mindepth 1 -type d -printf '%f ' 2>/dev/null)"

echo "→ origem:  $ORIGEM"
echo "→ destino: $HOST:$DESTINO"
echo "→ funções: $FUNCOES"
echo

if [ "${1:-}" = "--dry-run" ]; then
  echo "(dry-run: nada enviado)"
  exit 0
fi

# `rm -rf "$DESTINO"/*` antes de extrair faz o papel do --delete do rsync:
# função apagada do repositório precisa sumir do servidor, senão um endpoint
# removido continua de pé e ninguém nota.
tar czf - -C "$ORIGEM" . | ssh "$HOST" "
  set -e
  sudo mkdir -p '$DESTINO'
  sudo find '$DESTINO' -mindepth 1 -delete
  sudo tar xzf - -C '$DESTINO'
"

# --- aquecer o cache do deno antes de reiniciar ---------------------------
#
# O worker do edge-runtime baixa dependência remota (jsr/npm/https) na
# primeira vez que um import novo entra em produção. Isso não termina a
# tempo do boot do worker, e o container reinicia antes — ciclo que nunca
# fecha (visto em produção: a estreia de @supabase/supabase-js deixou só o
# registry.json de cada pacote no volume de cache, nunca o tarball extraído,
# e o edge-runtime caiu em restart loop). Rodar `deno cache` aqui, fora do
# runtime, contra o mesmo volume nomeado que ele usa, garante que o download
# termine antes do restart. Com o cache já quente (caso comum) isso não bate
# rede nenhuma — é só checagem local, e leva menos de 1s.
#
# DENO_VERSION tem que acompanhar a versão embutida no edge-runtime; se
# divergir, o cache fica num formato que o runtime não lê e o loop volta.
# Revalidar com `docker exec supabase-edge-functions-$SERVICO edge-runtime
# --version` sempre que a imagem supabase/edge-runtime for atualizada, e
# confirmar que denoland/deno:<versão> publica manifesto arm64 com
# `docker manifest inspect denoland/deno:<versão>` antes de trocar o número.
DENO_VERSION="2.1.4"
DENO_CACHE_VOLUME="${SERVICO}_deno-cache"

ENTRYPOINTS=""
for f in $FUNCOES; do
  ENTRYPOINTS="$ENTRYPOINTS $f/index.ts"
done

echo "→ aquecendo cache do deno ($DENO_VERSION) antes de reiniciar o runtime"
if ! ssh "$HOST" "
  set -e
  docker run --rm --platform linux/arm64 \
    -e DENO_DIR=/root/.cache/deno \
    -v '$DENO_CACHE_VOLUME':/root/.cache/deno \
    -v '$DESTINO':/home/deno/functions:ro \
    -w /home/deno/functions \
    denoland/deno:$DENO_VERSION \
    deno cache$ENTRYPOINTS
"; then
  echo "✗ falha ao aquecer o cache do deno — abortando antes de reiniciar o runtime." >&2
  echo "  o runtime antigo continua no ar, nada foi derrubado. Investigue o erro acima" >&2
  echo "  (rede até registry.npmjs.org/jsr.io, import novo quebrado, etc.) e rode o" >&2
  echo "  deploy de novo — não force o restart com o cache frio." >&2
  exit 1
fi
echo "✓ cache aquecido"

echo "→ reiniciando o edge-runtime"
ssh "$HOST" "docker restart supabase-edge-functions-$SERVICO" > /dev/null

echo "→ aguardando responder"
for _ in $(seq 1 30); do
  if curl -sf -o /dev/null "$URL_PUBLICA/functions/v1/health"; then
    echo "✓ health: $(curl -s "$URL_PUBLICA/functions/v1/health")"
    exit 0
  fi
  sleep 2
done

echo "✗ o runtime não respondeu em $URL_PUBLICA/functions/v1/health" >&2
exit 1
