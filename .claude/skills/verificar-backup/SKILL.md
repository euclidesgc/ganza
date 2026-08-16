---
name: verificar-backup
description: Verifica que o backup do banco do ganza existe, sai da VPS e RESTAURA de verdade num Postgres descartável. Use na Fase 0 e como rotina periódica — backup nunca restaurado não é backup.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Skill: verificar o backup

Objetivo: provar que dá para voltar. O plano lista infraestrutura própria como risco de nível alto (R9) por um motivo específico: **não existe backup gerenciado por trás**. O banco vai guardar extrato bancário, contrato de financiamento e o histórico de rotina de uma pessoa real — dado que não se recompõe.

> **A regra que resume esta skill: backup que nunca foi restaurado não é backup, é esperança.** A verificação abaixo é o que separa os dois.

## O que precisa estar verdadeiro

1. **`pg_dump` roda agendado** e o dump termina sem erro (confira o código de saída, não a existência do arquivo — dump truncado tem tamanho).
2. **A cópia sai da VPS.** O Garage S3 roda **no mesmo disco** do Postgres: ele é storage, não backup. Disco morreu, foram os dois. O destino tem que ser outro lugar — bucket externo (Backblaze B2, Cloudflare R2) ou a máquina local, e de preferência os dois.
3. **A restauração funciona.** É a única verificação que vale.
4. **Existe retenção**, com pelo menos um ponto de dias atrás. Corrupção silenciosa e `delete` errado só aparecem depois; sete dumps do mesmo dia não protegem contra isso.

## O teste de restauração (o único que conta)

```bash
docker run --rm -d --name restore-test -e POSTGRES_PASSWORD=x -p 55432:5432 postgres:15
# aguarde o healthcheck, então:
gunzip -c <dump-mais-recente>.sql.gz | psql -h localhost -p 55432 -U postgres -v ON_ERROR_STOP=1
```

Depois, confira o que importa — não só que "restaurou":

- as tabelas do `docs/plano.md` §7 existem;
- **a contagem de linhas das tabelas de dado real bate** com a de produção (transações, ocorrências, mensagens);
- **as políticas de RLS vieram junto** (`select tablename from pg_tables where schemaname='public' and rowsecurity=false` devolve vazio) — dump restaurado sem RLS é um banco aberto;
- os jobs de `pg_cron` estão lá, ou está documentado que precisam ser recriados à mão.

Derrube o container ao final (`docker rm -f restore-test`). O teste é descartável por desenho.

## Frequência

- **Fase 0:** uma vez, e a Fase 0 não fecha sem isso.
- **Depois:** a cada release, e sempre que uma migration mudar o schema de forma não trivial.

## Registre o resultado

Em `docs/deploy/coolify.md`, com data: o que foi restaurado, de qual dump, quanto tempo levou e o que faltou. **Quanto tempo levou** é o número que você vai querer no dia em que precisar de verdade — é ele que diz se a recuperação leva minutos ou uma tarde.
