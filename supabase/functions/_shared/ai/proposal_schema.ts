export interface Proposal {
  kind: string;
  payload: Record<string, unknown>;
}

export type ParseProposalsResult =
  | { ok: true; value: Proposal[] }
  | { ok: false; code: string };

const allowedKinds = new Set([
  'create_transaction',
  'create_task',
  'create_note',
  'create_routine',
  'create_commitment',
  'attach_document',
]);

const forbiddenPayloadKeys = new Set(['user_id', 'area_id', 'category_id']);
const maxProposals = 10;
const maxAmountCents = 1_000_000_000;
const maxDescriptionChars = 200;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function parseProposals(raw: unknown): ParseProposalsResult {
  if (!Array.isArray(raw)) {
    return { ok: false, code: 'raiz_nao_e_lista' };
  }
  if (raw.length > maxProposals) {
    return { ok: false, code: 'limite_de_propostas' };
  }

  const value: Proposal[] = [];
  for (const item of raw) {
    if (
      !isRecord(item) ||
      typeof item.kind !== 'string' ||
      !isRecord(item.payload)
    ) {
      return { ok: false, code: 'proposta_invalida' };
    }
    if (!allowedKinds.has(item.kind)) {
      return { ok: false, code: 'kind_nao_permitido' };
    }
    for (const key of Object.keys(item.payload)) {
      if (forbiddenPayloadKeys.has(key)) {
        return { ok: false, code: 'campo_nao_permitido' };
      }
    }
    if (item.kind === 'create_transaction') {
      const amount = item.payload.amount;
      if (
        !Number.isInteger(amount) ||
        (amount as number) <= 0 ||
        (amount as number) > maxAmountCents
      ) {
        return { ok: false, code: 'amount_invalido' };
      }
    }
    if (item.kind === 'create_routine') {
      const name = item.payload.name;
      if (typeof name !== 'string' || name.trim().length === 0) {
        return { ok: false, code: 'routine_name_invalido' };
      }
      const mode = item.payload.recurrence_mode;
      if (mode !== 'calendar' && mode !== 'interval_from_completion') {
        return { ok: false, code: 'recurrence_mode_invalido' };
      }
      if (mode === 'calendar') {
        const rule = item.payload.recurrence_rule;
        if (!Number.isInteger(rule) || (rule as number) < 1 || (rule as number) > 7) {
          return { ok: false, code: 'recurrence_rule_invalido' };
        }
      } else {
        const intervalDays = item.payload.interval_days;
        if (!Number.isInteger(intervalDays) || (intervalDays as number) <= 0) {
          return { ok: false, code: 'interval_days_invalido' };
        }
      }
    }
    if (item.kind === 'create_commitment') {
      const name = item.payload.name;
      if (typeof name !== 'string' || name.trim().length === 0) {
        return { ok: false, code: 'commitment_name_invalido' };
      }
      const direction = item.payload.direction;
      if (direction !== 'in' && direction !== 'out') {
        return { ok: false, code: 'commitment_direction_invalido' };
      }
      const mode = item.payload.value_mode;
      if (
        mode !== 'one_off' &&
        mode !== 'installment' &&
        mode !== 'fixed' &&
        mode !== 'variable'
      ) {
        return { ok: false, code: 'value_mode_invalido' };
      }
      if (mode === 'installment') {
        const total = item.payload.total_amount;
        const count = item.payload.installments_total;
        if (!Number.isInteger(total) || (total as number) <= 0) {
          return { ok: false, code: 'total_amount_invalido' };
        }
        if (!Number.isInteger(count) || (count as number) <= 0) {
          return { ok: false, code: 'installments_total_invalido' };
        }
      }
    }
    if (
      typeof item.payload.description === 'string' &&
      item.payload.description.length > maxDescriptionChars
    ) {
      return { ok: false, code: 'description_invalida' };
    }

    value.push({ kind: item.kind, payload: item.payload });
  }

  return { ok: true, value };
}
