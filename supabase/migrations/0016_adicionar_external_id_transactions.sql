-- O `external_id` guarda o identificador nativo do movimento (ex.: FITID do
-- OFX) para a importação deduplicar: reimportar o mesmo extrato não duplica.
alter table public.transactions
  add column external_id text;

create unique index transactions_user_external_idx
  on public.transactions (user_id, external_id)
  where external_id is not null;
