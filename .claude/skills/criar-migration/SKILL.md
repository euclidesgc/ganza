---
name: criar-migration
description: Cria uma migration SQL do ganza em supabase/migrations com RLS, política e verificação de que aplica limpo num banco vazio. Use sempre que uma feature precisar de tabela, coluna, índice, extensão ou job de pg_cron.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Skill: criar uma migration

Objetivo: alterar o schema sem surpresa em produção. A migration é a **única peça irreversível** do projeto — ela merece mais cuidado que qualquer tela.

**Regra que vem antes de todas: migration vai em PR separado, e primeiro.** Nunca no mesmo PR que UI. Um PR de migration se revisa de relance; um PR de migration + tela não se revisa.

## Passos

1. **Nome e lugar.** `supabase/migrations/NNNN_<verbo>_<alvo>.sql`, sequência com quatro dígitos, verbo no infinitivo (`0007_criar_routine_occurrences.sql`, `0012_adicionar_indice_conciliacao.sql`).
2. **Escreva o SQL.** Uma migration = uma intenção. Se o texto do nome precisa de "e", provavelmente são duas.
3. **RLS na mesma migration que cria a tabela** — não na seguinte:
   ```sql
   alter table <t> enable row level security;
   create policy "<t>_owner" on <t>
     for all using (user_id = auth.uid()) with check (user_id = auth.uid());
   ```
   Tabela sem `enable row level security` **e** sem política é migration rejeitada pelo CISO. Não existe "depois eu ponho".
4. **Tipos com armadilha neste produto:**
   - Dinheiro é `bigint` (centavos) ou `numeric` — **nunca** `float`/`double precision`.
   - Timestamp é `timestamptz`, sempre. Data de vencimento sem hora é `date`.
   - Estado terminal é `text` com `check` na lista fechada (ou enum), nunca texto livre.
   - `user_id uuid not null references auth.users(id)` — a coluna que a política usa não pode ser nullable.
5. **Índice nasce com a query que o exige.** Cite a query no PR. A conciliação varre por valor + janela de data sobre ~12 meses de histórico: esse índice tem dono e motivo.
6. **Extensão e `pg_cron`** são declarados na migration, e o que cada job agenda vai documentado. O job **só chama HTTP** (`pg_net` → endpoint do backend) — regra de negócio não mora em plpgsql.
7. **Prove que aplica limpo.** Suba um Postgres vazio, aplique **todas** as migrations em ordem, do zero. É exatamente o que a CI faz; rode antes dela.
8. **Migração de dado existente** (renomear coluna, mudar tipo) é passo separado e reversível: adicione o novo, popule, troque a leitura, remova o velho — em migrations distintas, não numa só.

## Antes de abrir o PR

- [ ] Aplica limpo num banco vazio, na ordem.
- [ ] Toda tabela nova tem RLS e política.
- [ ] Nenhum valor monetário em ponto flutuante.
- [ ] Nenhum segredo no SQL (nem em `comment`).
- [ ] O PR contém **só** migration.
