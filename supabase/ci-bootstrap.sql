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

-- Mesma ordem de coalesce do GoTrue/PostgREST real: primeiro a claim solta
-- (forma antiga, ainda usada por prova já escrita), depois o `sub` dentro do
-- JSON de `request.jwt.claims` (forma real, a que o GoTrue usa em produção).
-- Um stand-in que só entendesse a forma antiga faria `auth.uid()` devolver
-- NULL para toda prova de RLS escrita na forma real — a política de dono
-- rejeitaria o próprio dono e a prova "passaria" pelo motivo errado.
--
-- PG 15 não tem `pg_input_is_valid` (só a partir da 16) para checar um JSON
-- sem lançar exceção; por isso o bloco try/exception em plpgsql.
create or replace function auth.uid() returns uuid
  language plpgsql stable
as $$
declare
  claims jsonb;
begin
  begin
    claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  exception
    when invalid_text_representation then
      claims := null;
  end;

  return nullif(
    coalesce(
      current_setting('request.jwt.claim.sub', true),
      claims ->> 'sub'
    ),
    ''
  )::uuid;
end;
$$;
