# Deploy no Coolify — ganza

Estado da infraestrutura do ganza no servidor compartilhado. O passo a passo de decisão está na skill `subir-supabase`; aqui fica **o que existe hoje**.

> **O servidor é compartilhado** com `driva` e `love-secret`. Criar recursos novos do ganza é livre; tocar em recurso dos outros, não. Ver "Autonomia" no [`CLAUDE.md`](../../CLAUDE.md).

## A máquina

| | |
|---|---|
| Host | `64.181.165.16` — Oracle Ampere A1, **`aarch64`**, **2 vCPU**, **11,9 GB RAM**, 4 GB swap, 193 GB de disco |
| SSH | usuário **`ubuntu`** (`root` recusa); já configurado em `~/.ssh/config`, então `ssh 64.181.165.16` basta |
| Painel | `https://bmjtech.duckdns.org` (o `http://` faz 302 — sempre `https`) |
| API | token em `.env` (`COOLIFY_TOKEN`), gitignored |
| Projeto | **Ganza** · `djkdhce4d278jauiu7j3jo67` · ambiente `production` (`ftirflbtkyhksbminaxhq2dv`) |

**RAM sobra, CPU é o recurso escasso.** Dois núcleos servem também os builds dos outros projetos.

## Serviço `ganza-supabase` · `lqsjrqqs6r8rnggbvwpi4nuf`

Sete contêineres, todos `healthy`, **~840 MB de RAM somados** — bem abaixo dos ~2,5 GB que a stack completa custaria.

| Contêiner | Imagem | RAM |
|---|---|---|
| `supabase-db` | `supabase/postgres:15.8.1.085` | ~73 MB |
| `supabase-kong` | `kong/kong:3.9.1` | ~140 MB |
| `supabase-auth` | `supabase/gotrue:v2.186.0` | ~9 MB |
| `supabase-rest` | `postgrest/postgrest:v14.6` | ~12 MB |
| `supabase-storage` | `supabase/storage-api:v1.44.2` | ~131 MB |
| `supabase-meta` | `supabase/postgres-meta:v0.95.2` | ~83 MB |
| `supabase-studio` | `supabase/studio:2026.03.16` | ~173 MB |

### O que foi deliberadamente deixado de fora

O template oficial do Coolify sobe **15** serviços. Removidos, com o motivo:

| Fora | Por quê |
|---|---|
| `edge-functions` | a lógica é NestJS — decisão D1 do roadmap |
| `minio` + `minio-createbucket` | o storage passou a `STORAGE_BACKEND=file` num volume; o Garage S3 do servidor já existe se um dia precisar de S3 |
| `imgproxy` | não há transformação de imagem no escopo (`ENABLE_IMAGE_TRANSFORMATION=false`) |
| `supavisor` | pooler para um usuário é peso morto |
| `analytics` (Logflare) + `vector` | dois processos BEAM para observabilidade que não vamos ler. Eram `depends_on` de quase todo serviço — as dependências foram limpas junto |
| `realtime` | nada na v1 usa; entra quando um caso concreto pedir |

Ajustes que a remoção exigiu, e que **precisam ser refeitos se a stack for recriada**: tirar `supabase-vector` do `depends_on` do `db`, tirar `analytics` do `depends_on` de kong/rest/auth/meta/studio, e trocar o backend do storage de `s3`+minio para `file` em `/var/lib/storage`.

### Endpoint

```
http://supabasekong-lqsjrqqs6r8rnggbvwpi4nuf.64.181.165.16.sslip.io
```

Verificado funcionando: `/auth/v1/health` devolve GoTrue v2.186.0, `/rest/v1/` e `/storage/v1/bucket` devolvem 200 com a `apikey`.

> ### ⚠️ O domínio próprio ainda não está no ar — e por quê
>
> O alvo é **`https://supabase.ganza.bmjtech.duckdns.org`** (o DNS já resolve para o servidor; ver decisão D6 do roadmap).
>
> **A API v1 do Coolify não expõe o FQDN de um serviço.** Foi tentado, sem sucesso: `PATCH /services/{uuid}` com `domains` (*"This field is not allowed"*), `PATCH` das envs `SERVICE_FQDN_SUPABASEKONG*` (aceita, mas não regenera os labels do Traefik), redeploy com `force`, `PATCH /applications/{uuid}` (*"Application not found"* — sub-aplicação de serviço não é exposta) e criação de um serviço novo com o FQDN literal no compose (o Coolify sobrescreve com o `sslip.io`).
>
> **É um campo de UI.** Enquanto ele não for preenchido, o Traefik só gera router HTTP e serve o `TRAEFIK DEFAULT CERT` no 443 — daí o 503 em HTTPS.
>
> **Como resolver (30 segundos no painel):** projeto **Ganza** → serviço `ganza-supabase` → contêiner `supabase-kong` → campo de domínio → `https://supabase.ganza.bmjtech.duckdns.org` → salvar e redeployar. O `https://` é o que dispara o Let's Encrypt.
>
> Depois disso, atualize também a env `API_EXTERNAL_URL` (já está com o valor final) e confira `/auth/v1/health` no domínio novo.

## Chaves

Geradas pelo Coolify e visíveis em `GET /api/v1/services/{uuid}/envs`. **Nunca no repositório:**

- `SERVICE_SUPABASEANON_KEY` — a **anon key**, vai para o app Flutter.
- `SERVICE_SUPABASESERVICE_KEY` — a **service_role**, existe **só no backend NestJS**. Se aparecer no app ou numa variável de build do front, é incidente.
- `SERVICE_PASSWORD_POSTGRES`, `SERVICE_PASSWORD_JWT`, `SERVICE_USER_ADMIN`/`SERVICE_PASSWORD_ADMIN` (login do Studio).

## Ainda por fazer

- Domínio + TLS (acima).
- **SMTP** para os e-mails de autenticação — `SMTP_HOST`/`SMTP_USER`/`SMTP_PASS` estão vazios. Sem isso, confirmação de e-mail e recuperação de senha não saem.
- Backend NestJS em `api.ganza.bmjtech.duckdns.org` (F0.8).
- Front web em `ganza.bmjtech.duckdns.org` (Fase 8).
