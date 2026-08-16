-- Só para o CI: cria o mínimo do schema `auth` que as migrations referenciam.
-- No ambiente real quem cria `auth.users` e `auth.uid()` é o GoTrue, que não
-- roda no job de CI. Sem isto, o `references auth.users` falharia e o gate de
-- RLS nunca chegaria a rodar.
--
-- NÃO faz parte das migrations e nunca é aplicado em ambiente real.
create schema if not exists auth;
create schema if not exists extensions;
create schema if not exists vault;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text
);

create or replace function auth.uid() returns uuid
  language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
