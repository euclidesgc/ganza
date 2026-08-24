export interface LimitsRequest {
  taskType: string;
  content?: string;
  batchSize?: number;
}

export type LimitsResult =
  | { ok: true }
  | { ok: false; code: string; status: number };

const maxBatchSize = 100;
const maxInputChars = 4000;
const hourlyCallLimit = 60;
const dailyBudgetMicros = 1_000_000_000;

interface UsageRow {
  cost_micros: number;
}

interface QueryResult {
  count?: number | null;
  data?: UsageRow[] | null;
  error: unknown;
}

type Query = PromiseLike<QueryResult> & {
  gte: (column: string, value: string) => Query;
  eq: (column: string, value: string) => Query;
};

interface SupabaseLike {
  from: (table: string) => {
    select: (columns: string, opts?: { count?: string; head?: boolean }) => Query;
    insert: (row: Record<string, unknown>) => Promise<{ error: unknown }>;
  };
}

export async function assertWithinLimits(
  supabase: SupabaseLike,
  request: LimitsRequest,
): Promise<LimitsResult> {
  if (request.batchSize !== undefined && request.batchSize > maxBatchSize) {
    return { ok: false, code: 'batch_too_large', status: 413 };
  }
  if (request.content !== undefined && request.content.length > maxInputChars) {
    return { ok: false, code: 'input_too_large', status: 413 };
  }

  const hourAgo = new Date(Date.now() - 3_600_000).toISOString();
  const usage = await supabase
    .from('ai_usage')
    .select('id', { count: 'exact', head: true })
    .gte('created_at', hourAgo)
    .eq('status', 'success');
  if (usage.error) {
    return { ok: false, code: 'usage_query_failed', status: 500 };
  }
  if ((usage.count ?? 0) >= hourlyCallLimit) {
    await supabase.from('ai_usage').insert({
      task_type: request.taskType,
      status: 'refused',
      cost_micros: 0,
      rejection_code: 'ai_rate_limited',
    });
    return { ok: false, code: 'ai_rate_limited', status: 429 };
  }

  const dayStart = new Date();
  dayStart.setHours(0, 0, 0, 0);
  const budget = await supabase
    .from('ai_usage')
    .select('cost_micros')
    .gte('created_at', dayStart.toISOString());
  if (budget.error) {
    return { ok: false, code: 'usage_query_failed', status: 500 };
  }
  const total = (budget.data ?? []).reduce(
    (sum, row) => sum + (row.cost_micros ?? 0),
    0,
  );
  if (total > dailyBudgetMicros) {
    await supabase.from('ai_usage').insert({
      task_type: request.taskType,
      status: 'refused',
      cost_micros: 0,
      rejection_code: 'ai_budget_exceeded',
    });
    return { ok: false, code: 'ai_budget_exceeded', status: 429 };
  }

  return { ok: true };
}
