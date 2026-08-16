---
name: subir-supabase
description: Sobe ou atualiza a stack Supabase enxuta do ganza no Coolify (VPS ARM compartilhada) — escolha de serviços, checagem de arm64, RAM e envs. Use na Fase 0 e sempre que a stack precisar mudar de composição.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch
---

# Skill: subir a stack Supabase

Objetivo: colocar de pé a persistência do ganza numa VPS **que não é só nossa**, sem derrubar o que já roda nela.

> **Antes de qualquer comando que muda estado no servidor, pare e peça confirmação ao humano.** O host serve também `driva` e `love-secret`. Um comando no diretório errado derruba o projeto de outra pessoa. Ler estado (`docker ps`, `free -m`, API do Coolify) é livre; mudar não é.

## 1. Conheça a máquina antes de escolher os serviços

```bash
ssh 64.181.165.16 'uname -m; nproc; free -m; df -h /'
```

O que se espera hoje: **`aarch64`, 2 vCPU, ~12 GB RAM, ~150 GB livres**. Se divergir, pare e reavalie — o resto desta skill assume isso.

**RAM sobra; CPU é o recurso escasso.** Dois núcleos servem também os builds dos outros projetos. Serviço que fica ligado consumindo CPU à toa é mais caro aqui do que serviço que ocupa memória parada.

**Toda imagem precisa ter tag `arm64`** — confira antes de adicionar qualquer serviço:

```bash
docker manifest inspect <imagem> | grep -o '"architecture": "[a-z0-9]*"' | sort -u
```

## 2. A stack é enxuta por decisão

O template oficial de Supabase do Coolify sobe **15 serviços**. Nós não queremos 15.

| Serviço | Entra? | Por quê |
|---|---|---|
| `db` (Postgres) | **sim** | o produto |
| `auth` (GoTrue) | **sim** | login |
| `rest` (PostgREST) | **sim** | leitura do app com RLS |
| `storage` | **sim** | áudio, foto, PDF |
| `kong` | **sim** | porta de entrada única |
| `meta` + `studio` | **sim** | UI de banco; barato e evita SSH para olhar dado |
| `edge-functions` | **não** | a lógica é NestJS — esta é a decisão de arquitetura do projeto |
| `minio` | **não** | o Garage S3 do servidor já existe |
| `supavisor` (pooler) | **não** | pooler para um usuário é peso morto |
| `imgproxy` | **não** | não há transformação de imagem no escopo |
| `analytics` (Logflare) + `vector` | **não, se der** | dois processos BEAM para observabilidade que não vamos ler. **Atenção:** no compose oficial vários serviços têm `depends_on: analytics` — remover exige editar essas dependências, não só apagar o bloco. Se travar, mantenha e siga; não vale queimar a Fase 0 nisso. |
| `realtime` | **avalie** | nada no escopo da v1 usa. Deixe fora; entra quando um caso concreto pedir. |

Serviço novo entra com justificativa de RAM **e** CPU, escrita no PR.

## 3. Passos

1. Crie o projeto `Ganza` no Coolify e o ambiente `prod`.
2. Adicione o serviço a partir do template de Supabase e **edite o compose** para a lista acima antes do primeiro deploy — é muito mais barato tirar agora que depois.
3. Gere os segredos (`POSTGRES_PASSWORD`, `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, senha do Studio) **no painel**, nunca no repositório. O `anon key` vai para o app; o **`service_role` só para o backend**.
4. Domínio: `ganza.duckdns.org` com wildcard no DuckDNS, apontando para o servidor. Convenção do host: **apex = app · `api.` = backend · `hml.`/`api-hml.` = staging**. Confirme com `dig` antes de configurar o TLS.
5. Habilite as extensões na primeira migration: `pgcrypto`, `pg_cron`, `pg_net`, `supabase_vault`.
6. **Só então** aplique as migrations, em ordem, e confirme que toda tabela ficou com RLS.
7. Registre o resultado em `docs/deploy/coolify.md`: serviços que subiram, portas, envs (nomes, nunca valores), e o que foi deliberadamente deixado de fora.

## 4. Antes de considerar pronto

- [ ] `free -m` no servidor ainda mostra folga confortável **com a stack no ar**.
- [ ] Os projetos vizinhos continuam `running:healthy` na API do Coolify.
- [ ] O app alcança o Kong por HTTPS de fora da rede local (o OAuth do Google vai exigir isso).
- [ ] Nenhum segredo entrou no repositório.

> **Backup não é escopo** (decisão D4 do `docs/roadmap.md`). Não inclua rotina de `pg_dump` no checklist nem sugira uma — o humano já decidiu.
