import { createClient } from '@supabase/supabase-js';
import { nextDueDate } from '../_shared/routine_math.ts';

interface ApiError {
  code: string;
  message: string;
}

const ACTIONS = new Set(['done', 'postpone', 'skip', 'cancel']);

function errorResponse(code: string, message: string, status: number): Response {
  return Response.json({ error: { code, message } satisfies ApiError }, { status });
}

function parseDateOnly(value: string): Date {
  return new Date(`${value}T00:00:00Z`);
}

function nextDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + 1),
  );
}

// Separado do index.ts para poder ser testado sem subir servidor: o
// `Deno.serve` do index é a borda, isto é o comportamento.
export default async function handler(req: Request): Promise<Response> {
  if (req.method !== 'POST') {
    return errorResponse('method_not_allowed', 'use POST', 405);
  }

  const authorization = req.headers.get('Authorization');
  if (!authorization) {
    return errorResponse('unauthorized', 'sessão ausente', 401);
  }

  let raw: unknown;
  try {
    raw = await req.json();
  } catch {
    return errorResponse('invalid_json', 'corpo da requisição não é um JSON válido', 400);
  }
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    return errorResponse('invalid_json', 'corpo da requisição precisa ser um objeto JSON', 400);
  }

  const body = raw as Record<string, unknown>;

  const occurrenceId = body.occurrence_id;
  if (typeof occurrenceId !== 'string' || occurrenceId.length === 0) {
    return errorResponse(
      'invalid_occurrence_id',
      'occurrence_id precisa ser uma string não-vazia',
      400,
    );
  }

  const action = body.action;
  if (typeof action !== 'string' || !ACTIONS.has(action)) {
    return errorResponse(
      'invalid_action',
      'action precisa ser done, postpone, skip ou cancel',
      400,
    );
  }

  let newDueDate: string | null = null;
  if (action === 'postpone') {
    const value = body.due_date;
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return errorResponse('invalid_due_date', 'due_date precisa ser YYYY-MM-DD', 400);
    }
    newDueDate = value;
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !supabaseAnonKey) {
    return errorResponse('internal_error', 'configuração do servidor ausente', 500);
  }

  // JWT do usuário, nunca service_role: a RLS decide o dono da ocorrência e da
  // rotina, mesmo que o payload tente resolver ocorrência alheia.
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: occurrence, error: occurrenceError } = await supabase
    .from('routine_occurrences')
    .select('id, routine_id, sequence, due_date, status')
    .eq('id', occurrenceId)
    .maybeSingle();
  if (occurrenceError || !occurrence) {
    return errorResponse('ocorrencia_nao_encontrada', 'ocorrência não encontrada', 404);
  }

  if (occurrence.status !== 'pending' && occurrence.status !== 'postponed') {
    return errorResponse('ocorrencia_nao_resolvivel', 'a ocorrência já está resolvida', 409);
  }

  const { data: routine, error: routineError } = await supabase
    .from('routines')
    .select('recurrence_mode, recurrence_rule, interval_days')
    .eq('id', occurrence.routine_id)
    .maybeSingle();
  if (routineError || !routine) {
    return errorResponse('rotina_nao_encontrada', 'rotina não encontrada', 404);
  }

  const now = new Date();

  if (action === 'done') {
    const { error: doneError } = await supabase
      .from('routine_occurrences')
      .update({ status: 'done', completed_at: now.toISOString() })
      .eq('id', occurrenceId);
    if (doneError) {
      return errorResponse('write_failed', 'não foi possível marcar como feita', 500);
    }

    await supabase.from('occurrence_events').insert({
      routine_id: occurrence.routine_id,
      occurrence_id: occurrenceId,
      event: 'done',
      from_date: occurrence.due_date,
    });

    // A próxima conta da CONCLUSÃO (interval) ou do dia seguinte à data vencida
    // (calendar) — nunca da data original, para o atraso não distorcer o ciclo.
    const anchor = routine.recurrence_mode === 'calendar'
      ? nextDay(parseDateOnly(occurrence.due_date as string))
      : now;
    const nextDue = nextDueDate(
      routine.recurrence_mode,
      routine.recurrence_rule,
      routine.interval_days,
      anchor,
    );

    const { error: nextError } = await supabase.from('routine_occurrences').insert({
      routine_id: occurrence.routine_id,
      sequence: (occurrence.sequence as number) + 1,
      due_date: nextDue.toISOString().slice(0, 10),
    });
    if (nextError) {
      return errorResponse('write_failed', 'não foi possível gerar a próxima ocorrência', 500);
    }
  } else if (action === 'postpone') {
    const { error: postponeError } = await supabase
      .from('routine_occurrences')
      .update({ due_date: newDueDate })
      .eq('id', occurrenceId);
    if (postponeError) {
      return errorResponse('write_failed', 'não foi possível adiar a ocorrência', 500);
    }

    await supabase.from('occurrence_events').insert({
      routine_id: occurrence.routine_id,
      occurrence_id: occurrenceId,
      event: 'postponed',
      from_date: occurrence.due_date,
      to_date: newDueDate,
    });
  } else {
    const status = action === 'skip' ? 'skipped' : 'cancelled';
    const { error: resolveError } = await supabase
      .from('routine_occurrences')
      .update({ status })
      .eq('id', occurrenceId);
    if (resolveError) {
      return errorResponse('write_failed', 'não foi possível resolver a ocorrência', 500);
    }

    await supabase.from('occurrence_events').insert({
      routine_id: occurrence.routine_id,
      occurrence_id: occurrenceId,
      event: action,
      from_date: occurrence.due_date,
    });
  }

  return Response.json({ occurrence_id: occurrenceId, action }, { status: 200 });
}
