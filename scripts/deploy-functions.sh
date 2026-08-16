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

echo "→ origem:  $ORIGEM"
echo "→ destino: $HOST:$DESTINO"
echo "→ funções: $(find "$ORIGEM" -maxdepth 1 -mindepth 1 -type d -printf '%f ' 2>/dev/null)"
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
