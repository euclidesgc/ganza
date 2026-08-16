create extension if not exists pgcrypto with schema extensions;

-- pg_net e pg_cron sustentam o trabalho agendado: o cron chama o backend por
-- HTTP em vez de hospedar regra de negócio em plpgsql (ver CLAUDE.md).
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- Vault guarda os segredos que o banco precisa conhecer para chamar o backend.
create extension if not exists supabase_vault with schema vault;
