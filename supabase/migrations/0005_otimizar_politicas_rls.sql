-- O Security Advisor do Supabase acusa "Auth RLS Initialization Plan" em
-- profiles_owner e areas_owner: auth.uid() é re-avaliada linha a linha em vez
-- de virar InitPlan (uma vez por consulta). transactions_owner nasceu com o
-- mesmo padrão em 0004 — só não foi acusada porque a tabela ainda não existe
-- em produção. profiles e areas já estão em produção, então a correção vai
-- em migration nova: 0002/0004 já mergearam e não se reescrevem.
drop policy profiles_owner on public.profiles;

create policy profiles_owner on public.profiles
  for all
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy areas_owner on public.areas;

create policy areas_owner on public.areas
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy transactions_owner on public.transactions;

create policy transactions_owner on public.transactions
  for all
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
