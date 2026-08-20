#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE=(docker compose -f "$ROOT/infra/local/docker-compose.yml")
DB=("${COMPOSE[@]}" exec -T db psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1)
LOCAL_URL='http://127.0.0.1:54321'
LOCAL_USER_ID='11111111-1111-4111-8111-111111111111'
LOCAL_EMAIL='e2e@ganza.local'
JWT_SECRET='local-development-jwt-secret-with-at-least-32-characters'
CACHE_VOLUME='ganza-local_deno-cache'
ANON_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiZXhwIjo0MTAyNDQ0ODAwfQ.d_J3h-niwnX-XrnSujE0e_cZZ0qlybVYqi1dzzBAiGk'

usage() {
  echo "uso: scripts/local-supabase.sh up|reset|status|down|env"
}

wait_for_db() {
  local attempt
  for attempt in $(seq 1 60); do
    if "${DB[@]}" -tAc 'select 1' >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo 'Postgres local não ficou disponível.' >&2
  exit 1
}

wait_for_auth() {
  local attempt
  for attempt in $(seq 1 30); do
    if curl --fail --silent "$LOCAL_URL/auth/v1/health" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo 'GoTrue local não ficou disponível.' >&2
  exit 1
}

wait_for_functions() {
  local attempt
  for attempt in $(seq 1 30); do
    if curl --fail --silent "$LOCAL_URL/functions/v1/health" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo 'Edge Runtime local não ficou disponível.' >&2
  exit 1
}

apply_sql() {
  "${DB[@]}" < "$1"
}

jwt() {
  local header payload header64 payload64 signature
  header='{"alg":"HS256","typ":"JWT"}'
  payload="{\"sub\":\"$LOCAL_USER_ID\",\"email\":\"$LOCAL_EMAIL\",\"role\":\"authenticated\",\"aud\":\"authenticated\",\"exp\":4102444800}"
  header64=$(printf '%s' "$header" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  payload64=$(printf '%s' "$payload" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  signature=$(printf '%s' "$header64.$payload64" | openssl dgst -binary -sha256 -hmac "$JWT_SECRET" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
  printf '%s.%s.%s' "$header64" "$payload64" "$signature"
}

write_runtime_files() {
  local token
  token=$(jwt)
  mkdir -p "$ROOT/app/config" "$ROOT/infra/local"
  printf '%s\n' \
    '{' \
    '  "FLAVOR": "dev",' \
    '  "SUPABASE_URL": "http://10.0.2.2:54321",' \
    "  \"SUPABASE_ANON_KEY\": \"$ANON_KEY\"" \
    '}' > "$ROOT/app/config/local.json"
  printf 'SUPABASE_URL=%s\nANON_KEY=%s\nJWT_DONO=%s\nUSER_ID=%s\nE2E_EMAIL=%s\n' \
    "$LOCAL_URL" "$ANON_KEY" "$token" "$LOCAL_USER_ID" "$LOCAL_EMAIL" > "$ROOT/infra/local/.runtime.env"
}

warm_deno_cache() {
  local entrypoints=() entrypoint
  for entrypoint in "$ROOT"/supabase/functions/*/index.ts; do
    entrypoints+=("${entrypoint#"$ROOT/supabase/functions/"}")
  done

  docker run --rm \
    -v "$ROOT/supabase/functions:/home/deno/functions:ro" \
    -v "$CACHE_VOLUME:/root/.cache/deno" \
    -w /home/deno/functions \
    denoland/deno:2.1.4 deno cache "${entrypoints[@]}" >/dev/null
}

create_test_user() {
  local user_id
  user_id=$("${DB[@]}" -tAc "select id from auth.users where email = '$LOCAL_EMAIL'")

  if [ -z "$user_id" ]; then
    local attempt
    for attempt in $(seq 1 30); do
      if curl --fail --silent --show-error \
        -X POST "$LOCAL_URL/auth/v1/signup" \
        -H "apikey: $ANON_KEY" \
        -H 'Content-Type: application/json' \
        --data "{\"email\":\"$LOCAL_EMAIL\",\"password\":\"ganza-local-e2e-password\"}" >/dev/null; then
        user_id=$("${DB[@]}" -tAc "select id from auth.users where email = '$LOCAL_EMAIL'")
        break
      fi
      sleep 1
    done
  fi

  if [ -z "$user_id" ]; then
    echo 'Não foi possível criar o usuário local de E2E pelo GoTrue.' >&2
    exit 1
  fi

  LOCAL_USER_ID="$user_id"
  # Confirma só esta conta semente por id, direto no auth.users: com o mailer
  # sem autoconfirm global, é o jeito estável entre versões do GoTrue de dar
  # login a quem o próprio script cria — endereço novo continua exigindo o
  # código real, GOTRUE_MAILER_AUTOCONFIRM permanece 'false'.
  "${DB[@]}" -c "update auth.users set email_confirmed_at = now() where id = '$user_id' and email_confirmed_at is null" >/dev/null
}

initialize() {
  apply_sql "$ROOT/infra/local/bootstrap.sql"
  if [ "$("${DB[@]}" -tAc "select to_regclass('public.transactions') is not null")" != 't' ]; then
    local migration
    for migration in "$ROOT"/supabase/migrations/*.sql; do
      apply_sql "$migration"
    done
  fi
  "${COMPOSE[@]}" restart auth rest functions >/dev/null
  wait_for_auth
  create_test_user
  warm_deno_cache
  "${COMPOSE[@]}" restart rest functions studio >/dev/null
  wait_for_functions
  write_runtime_files
}

case "${1:-}" in
  up)
    "${COMPOSE[@]}" up -d
    wait_for_db
    initialize
    ;;
  reset)
    "${COMPOSE[@]}" down -v --remove-orphans
    "${COMPOSE[@]}" up -d
    wait_for_db
    initialize
    ;;
  status)
    "${COMPOSE[@]}" ps
    ;;
  down)
    "${COMPOSE[@]}" down -v --remove-orphans
    rm -f "$ROOT/infra/local/.runtime.env" "$ROOT/app/config/local.json"
    ;;
  env)
    [ -f "$ROOT/infra/local/.runtime.env" ] || { echo 'Rode up ou reset antes.' >&2; exit 1; }
    sed -n '1,$p' "$ROOT/infra/local/.runtime.env"
    ;;
  *)
    usage
    exit 1
    ;;
esac
