-- A taxa de cumprimento por rotina é uma projeção (view), não regra de
-- negócio em plpgsql: conta as ocorrências resolvidas. `security_invoker` faz a
-- view rodar com os privilégios do chamador, então a RLS das tabelas de baixo
-- (`routines`/`routine_occurrences`) continua decidindo o dono de cada linha.
create view public.routine_summaries
with (security_invoker = true)
as
select
  r.id as routine_id,
  r.name,
  count(ro.id) filter (where ro.status = 'done') as done_count,
  count(ro.id) filter (
    where ro.status in ('done', 'skipped', 'cancelled', 'missed')
  ) as resolved_count
from public.routines r
left join public.routine_occurrences ro on ro.routine_id = r.id
group by r.id, r.name;
