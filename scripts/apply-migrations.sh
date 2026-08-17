#!/usr/bin/env bash
#
# Aplica em produção as migrations pendentes de supabase/migrations/.
#
# O CI só prova que as migrations aplicam num Postgres descartável; este
# script é o único caminho até o banco real. Fala com o Postgres do mesmo
# jeito que scripts/deploy-functions.sh fala com o edge-runtime: ssh até a
# VPS, depois `docker exec` no contêiner — sem porta exposta, sem rsync.
#
# Controle do que já foi aplicado: supabase_migrations.schema_migrations,
# a convenção do Supabase (schema `supabase_migrations`, tabela
# `schema_migrations`, chave = nome do arquivo sem `.sql`). Cada migration
# roda dentro de `begin; ... commit;` junto com o registro na tabela de
# controle, então uma falha no meio do arquivo não deixa schema pela metade
# nem marca a migration como aplicada.
#
# O ALVO (--local ou --prod) é OBRIGATÓRIO e só existe como flag — nunca
# como variável de ambiente. Um `export` esquecido é invisível no comando
# digitado e não fica no histórico do shell; foi exatamente assim que uma
# corrida de teste bateu sem querer na produção real numa versão anterior
# deste script. Flag aparece no comando e é isso que evita o acidente se
# repetir.
#
# Uso:
#   scripts/apply-migrations.sh --local  [--status|--apply|--baseline ARQ...]
#   scripts/apply-migrations.sh --prod   [--status|--apply|--baseline ARQ...] [--yes]
#
#   --local                        fala com um Postgres desta máquina via `docker exec`
#                                   direto, sem ssh — só serve para testar o script
#                                   contra um Postgres descartável. NUNCA é produção.
#   --prod                         fala com a VPS de produção via ssh.
#   (sem ação) ou --status          lista as pendentes e sai — não muda nada (padrão)
#   --apply                         aplica as pendentes de verdade, uma transação por arquivo.
#                                   Com --prod, pede confirmação digitada antes de escrever.
#   --baseline ARQUIVO...           marca as migrations informadas como já aplicadas,
#                                   SEM reexecutá-las (uso: 0001-0003, já aplicadas à mão)
#   --yes                           pula a confirmação interativa de --prod --apply.
#                                   Só use depois de já ter visto o --status contra --prod.
#
# Variáveis (nunca escolhem o alvo — só refinam o alvo já escolhido por flag):
#   GANZA_HOST             endereço do ssh usado por --prod (default: a VPS do ganza)
#   GANZA_SUPABASE_UUID    uuid do serviço no Coolify (mesmo de deploy-functions.sh)
#   GANZA_DB_CONTAINER     nome do contêiner do Postgres
#   GANZA_DB_USER          role usada para conectar (a mesma do bootstrap de CI)

set -euo pipefail

ENDERECO_PROD_PADRAO="64.181.165.16"
SERVICO="${GANZA_SUPABASE_UUID:-lqsjrqqs6r8rnggbvwpi4nuf}"
CONTAINER="${GANZA_DB_CONTAINER:-supabase-db-$SERVICO}"
DB_USER="${GANZA_DB_USER:-supabase_admin}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR_MIGRATIONS="$RAIZ/supabase/migrations"

# Guarda: um SERVICO vazio ou curto demais monta um nome de contêiner
# incompleto e o `docker exec` erraria de alvo numa máquina compartilhada.
if [ -z "$SERVICO" ] || [ ${#SERVICO} -lt 8 ]; then
  echo "✗ GANZA_SUPABASE_UUID inválido — abortando antes de tocar no servidor." >&2
  exit 1
fi

[ -d "$DIR_MIGRATIONS" ] || { echo "✗ $DIR_MIGRATIONS não existe." >&2; exit 1; }

uso() {
  cat <<EOF
Uso: $(basename "$0") --local|--prod [--status | --apply | --baseline ARQUIVO...] [--yes]

O alvo é obrigatório e só se escolhe por flag:
  --local     Postgres desta máquina, via docker exec direto — só para teste, nunca produção.
  --prod      a VPS de produção, via ssh.

Ação (default: --status, se nenhuma for informada):
  --status               lista as migrations pendentes e sai — não muda nada
  --apply                aplica as pendentes de verdade, em ordem, uma transação por arquivo
  --baseline ARQUIVO...  marca as migrations informadas como já aplicadas, sem reexecutá-las
  --yes                  com --prod --apply, pula a confirmação digitada (use com cuidado)
EOF
}

erro() {
  echo "✗ $1" >&2
  exit 1
}

erro_sem_alvo() {
  echo "✗ nenhum alvo informado — o script não roda por omissão." >&2
  echo >&2
  echo "  escolha um, explicitamente:" >&2
  echo "    --local   Postgres descartável nesta máquina (docker exec direto, sem ssh) — para testar" >&2
  echo "    --prod    a VPS de produção (ssh $ENDERECO_PROD_PADRAO)" >&2
  echo >&2
  uso >&2
  exit 1
}

# --- argumentos ------------------------------------------------------

ALVO=""
ACAO=""
YES=0
BASELINE_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --local)
      [ -n "$ALVO" ] && erro "--local e --prod são exclusivos."
      ALVO="local"
      shift
      ;;
    --prod)
      [ -n "$ALVO" ] && erro "--local e --prod são exclusivos."
      ALVO="prod"
      shift
      ;;
    --status)
      [ -n "$ACAO" ] && erro "--status, --apply e --baseline são exclusivos."
      ACAO="status"
      shift
      ;;
    --apply)
      [ -n "$ACAO" ] && erro "--status, --apply e --baseline são exclusivos."
      ACAO="apply"
      shift
      ;;
    --baseline)
      [ -n "$ACAO" ] && erro "--status, --apply e --baseline são exclusivos."
      ACAO="baseline"
      shift
      while [ $# -gt 0 ] && [[ "$1" != --* ]]; do
        BASELINE_ARGS+=("$1")
        shift
      done
      ;;
    --yes)
      YES=1
      shift
      ;;
    -h|--help)
      uso
      exit 0
      ;;
    *)
      erro "argumento desconhecido: $1"
      ;;
  esac
done

[ -z "$ALVO" ] && erro_sem_alvo
[ -z "$ACAO" ] && ACAO="status"

if [ "$ALVO" = "prod" ]; then
  ENDERECO_SSH="${GANZA_HOST:-$ENDERECO_PROD_PADRAO}"
else
  ENDERECO_SSH=""
fi

# --- transporte: ssh até a VPS (--prod), ou docker local (--local, só teste) --

remoto() {
  # Roda o comando remoto passado em $1, herdando o stdin de quem chamou.
  local cmd="$1"
  if [ "$ALVO" = "local" ]; then
    bash -c "$cmd"
  else
    ssh -o ConnectTimeout=10 -o BatchMode=yes "$ENDERECO_SSH" "$cmd"
  fi
}

descricao_alvo() {
  if [ "$ALVO" = "local" ]; then
    echo "local (docker exec nesta máquina, contêiner '$CONTAINER')"
  else
    echo "PRODUÇÃO (ssh $ENDERECO_SSH, contêiner '$CONTAINER')"
  fi
}

psql_stdin() {
  # Envia o SQL recebido no stdin local para o psql dentro do contêiner.
  # ON_ERROR_STOP=1: qualquer erro do servidor derruba o pipe inteiro.
  remoto "docker exec -i '$CONTAINER' psql -U '$DB_USER' -d postgres -v ON_ERROR_STOP=1 -q"
}

psql_query() {
  # Roda uma única consulta e devolve o resultado em tuples-only/unaligned.
  printf '%s\n' "$1" | remoto "docker exec -i '$CONTAINER' psql -U '$DB_USER' -d postgres -v ON_ERROR_STOP=1 -tAq"
}

checar_conexao() {
  echo "→ checando acesso ao Postgres — alvo: $(descricao_alvo)" >&2
  if ! remoto "docker exec '$CONTAINER' pg_isready -U '$DB_USER'" > /dev/null 2>&1; then
    echo "✗ não consegui falar com o Postgres — alvo: $(descricao_alvo). ssh caiu ou o contêiner não responde." >&2
    exit 1
  fi
}

# --- tabela de controle -----------------------------------------------

tabela_controle_existe() {
  local r
  r="$(psql_query "select to_regclass('supabase_migrations.schema_migrations') is not null;")"
  [ "$r" = "t" ]
}

garantir_tabela_controle() {
  # Só é chamada pelos modos que de fato escrevem (--apply / --baseline), e
  # só depois de qualquer confirmação exigida já ter passado.
  psql_stdin <<'SQL'
create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations (
  version text primary key,
  applied_at timestamptz not null default now()
);
SQL
}

listar_aplicadas() {
  if tabela_controle_existe; then
    psql_query "select version from supabase_migrations.schema_migrations order by version;"
  fi
}

# --- arquivos no diretório -----------------------------------------------

listar_arquivos() {
  # Ordem lexicográfica do nome — é a ordem de aplicação. Nunca uma lista
  # fixa: o que estiver em supabase/migrations/*.sql no momento da corrida.
  find "$DIR_MIGRATIONS" -maxdepth 1 -name '*.sql' -type f -printf '%f\n' | sort
}

versao_de() {
  echo "${1%.sql}"
}

pendentes() {
  local aplicadas="$1" arquivo v
  while IFS= read -r arquivo; do
    [ -z "$arquivo" ] && continue
    v="$(versao_de "$arquivo")"
    if ! grep -qxF "$v" <<< "$aplicadas"; then
      echo "$arquivo"
    fi
  done < <(listar_arquivos)
}

# --- comandos --------------------------------------------------------

cmd_status() {
  checar_conexao
  local aplicadas pend
  aplicadas="$(listar_aplicadas)"
  pend="$(pendentes "$aplicadas")"

  echo
  echo "Aplicadas (segundo supabase_migrations.schema_migrations):"
  if [ -z "$aplicadas" ]; then
    echo "  (nenhuma — tabela de controle vazia ou ainda não existe)"
  else
    while IFS= read -r v; do [ -n "$v" ] && echo "  ✓ $v"; done <<< "$aplicadas"
  fi

  echo
  if [ -z "$pend" ]; then
    echo "Pendentes: nenhuma. Banco em dia."
  else
    echo "Pendentes (--apply aplicaria, nesta ordem):"
    while IFS= read -r f; do [ -n "$f" ] && echo "  · $f"; done <<< "$pend"
  fi
}

aplicar_um() {
  local arquivo="$1" versao caminho
  versao="$(versao_de "$arquivo")"
  caminho="$DIR_MIGRATIONS/$arquivo"
  echo "→ $arquivo"
  if ! { printf 'begin;\n'; cat "$caminho"; printf '\n'; printf "insert into supabase_migrations.schema_migrations (version) values ('%s');\n" "$versao"; printf 'commit;\n'; } | psql_stdin; then
    echo "✗ falhou aplicando $arquivo — a transação desse arquivo foi revertida (nada dele foi commitado, e não foi marcado como aplicado). As migrations anteriores já aplicadas nesta corrida permanecem. Corrija o arquivo e rode --apply de novo." >&2
    exit 1
  fi
  echo "  ✓ $arquivo aplicada e registrada"
}

confirmar_producao() {
  # Única barreira antes de qualquer escrita real em produção via --apply.
  # Exige resposta digitada de propósito; --yes pula isso conscientemente.
  local pend="$1"
  if [ "$YES" -eq 1 ]; then
    echo "→ --yes informado: pulando a confirmação interativa." >&2
    return 0
  fi
  echo >&2
  echo "isso vai escrever em $(descricao_alvo):" >&2
  while IFS= read -r f; do [ -n "$f" ] && echo "  · $f" >&2; done <<< "$pend"
  echo >&2
  printf "Digite APLICAR para confirmar: " >&2
  local resposta
  if ! read -r resposta; then
    echo "✗ não consegui ler uma resposta (sem terminal interativo?). Rode de novo com --yes se já validou o --status e tem certeza." >&2
    exit 1
  fi
  if [ "$resposta" != "APLICAR" ]; then
    echo "✗ confirmação não recebida ('$resposta' ≠ 'APLICAR') — nada foi aplicado." >&2
    exit 1
  fi
  echo "✓ confirmado." >&2
}

cmd_apply() {
  checar_conexao
  local aplicadas pend
  aplicadas="$(listar_aplicadas)"
  pend="$(pendentes "$aplicadas")"

  if [ -z "$pend" ]; then
    echo "✓ nada pendente — banco já está em dia."
    return 0
  fi

  echo "→ vou aplicar, em ordem:"
  while IFS= read -r f; do [ -n "$f" ] && echo "  · $f"; done <<< "$pend"
  echo

  if [ "$ALVO" = "prod" ]; then
    confirmar_producao "$pend"
  fi

  garantir_tabela_controle

  while IFS= read -r arquivo; do
    [ -z "$arquivo" ] && continue
    aplicar_um "$arquivo"
  done <<< "$pend"

  echo
  echo "✓ todas as pendentes foram aplicadas."
}

cmd_baseline() {
  local args=("${BASELINE_ARGS[@]}") arquivo versao aplicadas
  if [ ${#args[@]} -eq 0 ]; then
    echo "✗ --baseline exige ao menos um arquivo (ex.: 0001_habilitar_extensoes.sql)." >&2
    exit 1
  fi

  checar_conexao
  garantir_tabela_controle
  aplicadas="$(listar_aplicadas)"

  for arquivo in "${args[@]}"; do
    arquivo="$(basename "$arquivo")"
    [[ "$arquivo" == *.sql ]] || arquivo="${arquivo}.sql"
    if [ ! -f "$DIR_MIGRATIONS/$arquivo" ]; then
      echo "✗ $arquivo não existe em supabase/migrations/ — abortando baseline sem marcar nada." >&2
      exit 1
    fi
    versao="$(versao_de "$arquivo")"
    if grep -qxF "$versao" <<< "$aplicadas"; then
      echo "· $arquivo já estava marcada como aplicada — nada a fazer."
      continue
    fi
    printf "insert into supabase_migrations.schema_migrations (version) values ('%s') on conflict (version) do nothing;\n" "$versao" | psql_stdin
    echo "✓ $arquivo marcada como aplicada (sem executar o conteúdo)"
  done
}

case "$ACAO" in
  status) cmd_status ;;
  apply) cmd_apply ;;
  baseline) cmd_baseline ;;
esac
