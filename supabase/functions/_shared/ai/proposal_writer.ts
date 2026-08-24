import { parseProposals, type Proposal } from './proposal_schema.ts';
import { resolveCategory } from './resolve_category.ts';
import { nextDueDate } from '../routine_math.ts';
import { amortizationSchedule } from '../finance_math.ts';

function addMonthsIso(date: Date, months: number): string {
  const d = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, date.getUTCDate()),
  );
  return d.toISOString().slice(0, 10);
}

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
  } else if (data.kind === 'create_commitment') {
    const payload = data.payload;
    const commitmentRow: Record<string, unknown> = {
      name: payload.name,
      direction: payload.direction,
      value_mode: payload.value_mode,
    };
    if (payload.total_amount !== undefined) {
      commitmentRow.total_amount = payload.total_amount;
    }
    if (payload.installments_total !== undefined) {
      commitmentRow.installments_total = payload.installments_total;
    }
    if (payload.interest_rate_monthly !== undefined) {
      commitmentRow.interest_rate_monthly = payload.interest_rate_monthly;
    }
    if (payload.amortization_system !== undefined) {
      commitmentRow.amortization_system = payload.amortization_system;
    }

    const { data: insertedCommitment, error: commitmentError } = await supabase
      .from('commitments')
      .insert(commitmentRow)
      .select('id')
      .single();
    if (commitmentError || !insertedCommitment?.id) {
      return { ok: false, code: 'write_failed' };
    }

    const commitmentId = insertedCommitment.id as string;
    const occurrences: Record<string, unknown>[] = [];

    if (payload.value_mode === 'installment') {
      const total = payload.total_amount as number;
      const count = payload.installments_total as number;
      const rate = typeof payload.interest_rate_monthly === 'number'
        ? payload.interest_rate_monthly
        : 0;
      const system = payload.amortization_system === 'sac' ? 'sac' : 'price';
      const schedule = amortizationSchedule(system, total, count, rate);
      for (const row of schedule) {
        occurrences.push({
          commitment_id: commitmentId,
          sequence: row.period,
          due_date: addMonthsIso(new Date(), row.period),
          expected_amount: row.installment,
          estimate_source: rate > 0 ? 'contract' : 'manual',
        });
      }
    } else {
      occurrences.push({
        commitment_id: commitmentId,
        sequence: 1,
        due_date: addMonthsIso(new Date(), 1),
        expected_amount: payload.total_amount ?? null,
        estimate_source: payload.value_mode === 'variable' ? 'average' : 'contract',
      });
    }

    if (occurrences.length > 0) {
      const { error: occurrencesError } = await supabase
        .from('commitment_occurrences')
        .insert(occurrences);
      if (occurrencesError) {
        return { ok: false, code: 'write_failed' };
      }
    }

    resultingId = commitmentId;
    resultingType = 'commitment';
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
