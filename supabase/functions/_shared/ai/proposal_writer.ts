import { parseProposals, type Proposal } from './proposal_schema.ts';

export type WriteResult =
  | { ok: true; count: number }
  | { ok: false; code: string };

interface ProposalRow {
  id: string;
  status: string;
  kind: string;
  payload: Record<string, unknown>;
}

interface SupabaseLike {
  from: (table: string) => {
    select: (...args: unknown[]) => QueryLike;
    insert: (rows: unknown) => PromiseLike<{ error: unknown }>;
    update: (row: Record<string, unknown>) => QueryLike;
  };
}

type QueryLike =
  & PromiseLike<{
    data: ProposalRow[] | null;
    error: unknown;
  }>
  & {
    eq: (column: string, value: string) => QueryLike;
    maybeSingle: () => PromiseLike<{ data: ProposalRow | null; error: unknown }>;
  };

export async function writeProposals(
  supabase: SupabaseLike,
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
  supabase: SupabaseLike,
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

  if (data.kind === 'create_transaction') {
    const payload = data.payload;
    const occurredAt = typeof payload.occurred_at === 'string'
      ? payload.occurred_at
      : new Date().toISOString();
    const { error: insertError } = await supabase.from('transactions').insert({
      direction: payload.direction,
      amount: payload.amount,
      description: payload.description,
      occurred_at: occurredAt,
      source: 'chat',
    });
    if (insertError) {
      return { ok: false, code: 'write_failed' };
    }
  }

  const { error: updateError } = await supabase
    .from('proposed_actions')
    .update({ status: 'confirmed' })
    .eq('id', proposalId);
  if (updateError) {
    return { ok: false, code: 'write_failed' };
  }

  return { ok: true, count: 1 };
}
