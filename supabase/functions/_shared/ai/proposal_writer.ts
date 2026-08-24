import { parseProposals, type Proposal } from './proposal_schema.ts';

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
    const { data: inserted, error: insertError } = await supabase
      .from('transactions')
      .insert({
        direction: payload.direction,
        amount: payload.amount,
        description: payload.description,
        occurred_at: occurredAt,
        source: 'chat',
      })
      .select('id')
      .single();
    if (insertError) {
      return { ok: false, code: 'write_failed' };
    }
    resultingId = inserted?.id ?? null;
    resultingType = 'transaction';
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
