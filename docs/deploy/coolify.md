# HML no Coolify — ganza

Estado da infraestrutura do ganza no servidor compartilhado. O passo a passo de decisão está na skill `subir-supabase`; aqui fica **o que existe hoje**.

> **O servidor é compartilhado** com `driva` e `love-secret`. Criar recursos novos do ganza é livre; tocar em recurso dos outros, não. Ver "Autonomia" no [`CLAUDE.md`](../../CLAUDE.md).

## A máquina

| | |
|---|---|
| Host | `64.181.165.16` — Oracle Ampere A1, **`aarch64`**, **2 vCPU**, **11,9 GB RAM**, 4 GB swap, 193 GB de disco |
| SSH | usuário **`ubuntu`** (`root` recusa); já configurado em `~/.ssh/config`, então `ssh 64.181.165.16` basta |
| Painel | `https://bmjtech.duckdns.org` (o `http://` faz 302 — sempre `https`) |
| API | token em `.env` (`COOLIFY_TOKEN`), gitignored |
| Projeto | **Ganza** · `djkdhce4d278jauiu7j3jo67` · ambiente remoto de homologação (HML) |

**RAM sobra, CPU é o recurso escasso.** Dois núcleos servem também os builds dos outros projetos.

## Serviço `ganza-supabase` · `lqsjrqqs6r8rnggbvwpi4nuf`

Oito contêineres, todos `healthy` — bem abaixo dos ~2,5 GB que a stack completa custaria. O `edge-functions` voltou na decisão **D10**, quando a lógica migrou do NestJS para ele.

| Contêiner | Imagem | RAM |
|---|---|---|
| `supabase-db` | `supabase/postgres:15.8.1.085` | ~73 MB |
| `supabase-kong` | `kong/kong:3.9.1` | ~140 MB |
| `supabase-auth` | `supabase/gotrue:v2.186.0` | ~9 MB |
| `supabase-rest` | `postgrest/postgrest:v14.6` | ~12 MB |
| `supabase-storage` | `supabase/storage-api:v1.44.2` | ~131 MB |
| `supabase-meta` | `supabase/postgres-meta:v0.95.2` | ~83 MB |
| `supabase-studio` | `supabase/studio:2026.03.16-sha-5528817` | ~173 MB |
| `supabase-edge-functions` | `supabase/edge-runtime:v1.71.2` | ~60 MB |

> ### O painel mostra "Degraded" — e isso é esperado
>
> O Coolify guardou no banco dele os cards dos 15 serviços do template original. Os 8 que removemos do compose aparecem como **Exited**, e o cabeçalho do serviço fica **Degraded** por causa deles. **Não é falha:** "Exited" ali significa "não faz parte da stack".
>
> O `Supabase Rest` aparece como *Running (unknown, excluded)* — a imagem do PostgREST não traz healthcheck. Ele responde 200 normalmente.
>
> Limpar os órfãos exigiria editar o banco do próprio Coolify (que serve driva e love-secret) ou recriar o serviço. Nenhum dos dois vale o risco por um rótulo. **Confira a saúde pelos 7 contêineres da tabela acima, não pelo cabeçalho.**

### O que foi deliberadamente deixado de fora

O template oficial do Coolify sobe **15** serviços. Removidos, com o motivo:

| Fora | Por quê |
|---|---|
| `minio` + `minio-createbucket` | o storage passou a `STORAGE_BACKEND=file` num volume; o Garage S3 do servidor já existe se um dia precisar de S3 |
| `imgproxy` | não há transformação de imagem no escopo (`ENABLE_IMAGE_TRANSFORMATION=false`) |
| `supavisor` | pooler para um usuário é peso morto |
| `analytics` (Logflare) + `vector` | dois processos BEAM para observabilidade que não vamos ler. Eram `depends_on` de quase todo serviço — as dependências foram limpas junto |
| `realtime` | nada na v1 usa; entra quando um caso concreto pedir |

Ajustes que a remoção exigiu, e que **precisam ser refeitos se a stack for recriada**: tirar `supabase-vector` do `depends_on` do `db`, tirar `analytics` do `depends_on` de kong/rest/auth/meta/studio, e trocar o backend do storage de `s3`+minio para `file` em `/var/lib/storage`.

### Endpoint

```
https://supabase.ganza.bmjtech.duckdns.org
```

TLS por Let's Encrypt (`CN = supabase.ganza.bmjtech.duckdns.org`, emitido em 16/08/2026, válido até 14/11/2026, renovação automática pelo Traefik). Verificado com a `apikey`: `/auth/v1/health`, `/rest/v1/` e `/storage/v1/bucket` devolvem **200**.

> **O domínio de um serviço é campo de UI — a API v1 do Coolify não o expõe.** Foi tentado, sem sucesso: `PATCH /services/{uuid}` com `domains` (*"This field is not allowed"*), `PATCH` das envs `SERVICE_FQDN_SUPABASEKONG*` (aceita, mas não regenera os labels do Traefik), redeploy com `force`, `PATCH /applications/{uuid}` (*"Application not found"* — sub-aplicação de serviço não é exposta) e criação de um serviço novo com o FQDN literal no compose (o Coolify sobrescreve com o `sslip.io`).
>
> **O caminho que funciona:** projeto → serviço → contêiner `supabase-kong` → *Edit domain* → **Protocol `https`**, Domain sem esquema, Port `8000`, Path vazio → Save → **Redeploy**. É o `https` que dispara o Let's Encrypt; com `http` o Traefik só cria router HTTP e serve o `TRAEFIK DEFAULT CERT` no 443.
>
> O redeploy em si **pode** ser disparado pela API (`POST /api/v1/deploy?uuid=...&force=true`).

## Chaves

Geradas pelo Coolify e visíveis em `GET /api/v1/services/{uuid}/envs`. **Nunca no repositório:**

- `SERVICE_SUPABASEANON_KEY` — a **anon key**, vai para o app Flutter.
- `SERVICE_SUPABASESERVICE_KEY` — a **service_role**. Chega pronta ao runtime das functions; **nunca** ao app. Se aparecer no cliente ou numa variável de build do front, é incidente.
- `SERVICE_PASSWORD_POSTGRES`, `SERVICE_PASSWORD_JWT`, `SERVICE_USER_ADMIN`/`SERVICE_PASSWORD_ADMIN` (login do Studio).

## Edge Functions

A lógica de servidor roda no `supabase-edge-functions`, dentro da própria stack (decisão **D10** do roadmap). Não há aplicação separada no Coolify.

**Publicar** é `scripts/deploy-functions.sh`: no self-hosted não existe `supabase functions deploy` — o runtime serve o que estiver no volume, então o script sincroniza `supabase/functions/` para `/data/coolify/services/<uuid>/volumes/functions/` e reinicia o contêiner.

Detalhes que custaram tempo e ficam registrados:

- O servidor **não tem `rsync`**. O script usa `tar` sobre ssh — instalar dependência numa máquina compartilhada com outros dois projetos custa mais que a alternativa.
- O diretório pertence ao `root`; o `ubuntu` tem **sudo sem senha**, e o script usa isso.
- O script **apaga o destino antes de extrair** (o papel do `--delete`): função removida do repositório precisa sumir do servidor, senão um endpoint apagado continua de pé e ninguém nota.
- O runtime já recebe `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL` e `SUPABASE_JWT_SECRET` — não invente configuração para o que já existe.

Verificado: `GET /functions/v1/health` com `apikey` devolve `{"status":"ok","database":"reachable"}`; rota inexistente devolve 404.

## Autenticação

Conta única (`euclides.catunda@gmail.com`), criada com `ENABLE_EMAIL_AUTOCONFIRM=true` e **cadastro fechado em seguida** com `DISABLE_SIGNUP=true` — o app é monousuário por desenho, e endpoint de signup aberto na internet é convite sem porteiro. Verificado: a tentativa devolve `422 signup_disabled`.

> **Ao mexer em env do GoTrue, espere o redeploy terminar antes de testar.** O contêiner antigo continua servindo durante a troca: um teste feito no meio da janela mostrou signup funcionando com a config nova já salva. A stack tem **oito** contêineres — conte-os antes de concluir qualquer coisa.

Redefinir senha, enquanto não há SMTP: pelo Studio, em `https://supabase.ganza.bmjtech.duckdns.org`.

## Ainda por fazer

- **SMTP** para os e-mails de autenticação — `SMTP_HOST`/`SMTP_USER`/`SMTP_PASS` estão vazios. Sem isso, confirmação de e-mail e recuperação de senha não saem.
- Front web em `ganza.bmjtech.duckdns.org` (Fase 8).
