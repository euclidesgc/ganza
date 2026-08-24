import { parseProposals, type Proposal } from './proposal_schema.ts';
import { resolveCategory } from './resolve_category.ts';
import { nextDueDate } from '../routine_math.ts';

export type WriteResult =
  | { ok: true; count: number }
  | { ok: false; code: string };

export async function writeProposals(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  messageId: string,
  raw: unknown,
): Promise<WriteResult> {
  const parsed = parseProposals(raw);
  if (!parsed.ok) {
    return { ok: false, code: parsed.code };
  }

  const rows = parsed.value.map((proposal: Proposal, index: number) => ({
    message_id: messageId,
    sequence: index + 1,
    kind: proposal.kind,
    payload: proposal.payload,
  }));

  const { error } = await supabase.from('proposed_actions').insert(rows);
  if (error) {
    return { ok: false, code: 'write_failed' };
  }
  return { ok: true, count: rows.length };
}

export async function confirmProposal(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  proposalId: string,
): Promise<WriteResult> {
  const { data, error } = await supabase
    .from('proposed_actions')
    .select('*')
    .eq('id', proposalId)
    .maybeSingle();
  if (error || !data) {
    return { ok: false, code: 'proposta_nao_encontrada' };
  }
  if (data.status !== 'pending') {
    return { ok: false, code: 'proposta_nao_pendente' };
  }

  const revalidated = parseProposals([{ kind: data.kind, payload: data.payload }]);
  if (!revalidated.ok) {
    return { ok: false, code: 'payload_invalido' };
  }

  let resultingId: string | null = null;
  let resultingType: string | null = null;

  if (data.kind === 'create_transaction') {
    const payload = data.payload;
    const occurredAt = typeof payload.occurred_at === 'string'
      ? payload.occurred_at
      : new Date().toISOString();

    const category = await resolveCategory(
      supabase,
      typeof payload.description === 'string' ? payload.description : '',
    );
    if (!category.ok) {
      return { ok: false, code: category.code };
    }

    const transactionRow: Record<string, unknown> = {
      direction: payload.direction,
      amount: payload.amount,
      description: payload.description,
      occurred_at: occurredAt,
      source: 'chat',
    };
    if (category.categoryId !== null) {
      transactionRow.category_id = category.categoryId;
    }

    const { data: inserted, error: insertError } = await supabase
      .from('transactions')
      .insert(transactionRow)
      .select('id')
      .single();
    if (insertError) {
      return { ok: false, code: 'write_failed' };
    }
    resultingId = inserted?.id ?? null;
    resultingType = 'transaction';
  } else if (data.kind === 'create_routine') {
    const payload = data.payload;
    const routineRow: Record<string, unknown> = {
      name: payload.name,
      recurrence_mode: payload.recurrence_mode,
    };
    if (payload.recurrence_mode === 'calendar') {
      routineRow.recurrence_rule = payload.recurrence_rule;
    } else {
      routineRow.interval_days = payload.interval_days;
    }

    const { data: insertedRoutine, error: routineError } = await supabase
      .from('routines')
      .insert(routineRow)
      .select('id')
      .single();
    if (routineError) {
      return { ok: false, code: 'write_failed' };
    }

    const routineId = insertedRoutine?.id as string | undefined;
    if (!routineId) {
      return { ok: false, code: 'write_failed' };
    }

    const dueDate = nextDueDate(
      payload.recurrence_mode,
      payload.recurrence_mode === 'calendar' ? payload.recurrence_rule : null,
      payload.recurrence_mode === 'interval_from_completion' ? payload.interval_days : null,
      new Date(),
    );

    const { error: occurrenceError } = await supabase
      .from('routine_occurrences')
      .insert({
        routine_id: routineId,
        sequence: 1,
        due_date: dueDate.toISOString().slice(0, 10),
      });
    if (occurrenceError) {
      return { ok: false, code: 'write_failed' };
    }

    resultingId = routineId;
    resultingType = 'routine';
  }

  const updateRow: Record<string, unknown> = { status: 'confirmed' };
  if (resultingId !== null) updateRow.resulting_id = resultingId;
  if (resultingType !== null) updateRow.resulting_type = resultingType;

  const { error: updateError } = await supabase
    .from('proposed_actions')
    .update(updateRow)
    .eq('id', proposalId);
  if (updateError) {
    return { ok: false, code: 'write_failed' };
  }

  return { ok: true, count: 1 };
}

export async function cancelProposal(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  proposalId: string,
): Promise<WriteResult> {
  const { data, error } = await supabase
    .from('proposed_actions')
    .select('*')
    .eq('id', proposalId)
    .maybeSingle();
  if (error || !data) {
    return { ok: false, code: 'proposta_nao_encontrada' };
  }
  if (data.status !== 'pending') {
    return { ok: false, code: 'proposta_nao_pendente' };
  }

  const { error: updateError } = await supabase
    .from('proposed_actions')
    .update({ status: 'cancelled' })
    .eq('id', proposalId);
  if (updateError) {
    return { ok: false, code: 'write_failed' };
  }

  return { ok: true, count: 1 };
}
