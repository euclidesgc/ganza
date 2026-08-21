# T5.2 — prova de que o teste falha sem a mudança

Data: 2026-08-21. Alvo: `infra/local/docker-compose.yml`, serviço
`functions` — adição de `PLUGGY_CLIENT_ID`/`PLUGGY_CLIENT_SECRET` por
interpolação (`${...}`) a partir de `infra/local/.env`.

## Comando de prova

```
set -a; . ./infra/local/.runtime.env; set +a
curl -s -o /dev/null -w '%{http_code}\n' -X POST "$SUPABASE_URL/functions/v1/bank-connections" \
  -H "Authorization: Bearer $JWT_DONO" -H 'Content-Type: application/json' \
  -d '{"action":"connect_token"}'
```

Nunca coletar o corpo da resposta — no caminho de sucesso ele traz a
`apiKey` da Pluggy.

## Antes (sem as variáveis no serviço `functions`)

```
503
```

O `bank-connections` respondia `missing_configuration` — a Pluggy nunca era
chamada porque `Deno.env.get('PLUGGY_CLIENT_ID')`/`PLUGGY_CLIENT_SECRET`
voltavam `undefined` dentro do contêiner.

## Depois (`docker compose -f infra/local/docker-compose.yml up -d functions` recriando o contêiner)

```
200
```

O `200` prova duas coisas ao mesmo tempo: que o compose agora repassa as
duas variáveis ao contêiner `functions`, e que o par Client ID/Secret é
válido na Pluggy — sem precisar de um `curl` de autenticação em separado,
que exporia o segredo no argv do processo.
