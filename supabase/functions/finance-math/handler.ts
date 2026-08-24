import { amortizationSchedule } from '../_shared/finance_math.ts';

interface ApiError {
  code: string;
  message: string;
}

function errorResponse(code: string, message: string, status: number): Response {
  return Response.json({ error: { code, message } satisfies ApiError }, { status });
}

// O handler não calcula nada: a matemática mora em `_shared/finance_math.ts`
// (invariante nº 3 — determinístico, nunca IA). Aqui só se valida a borda.
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

  const mode = body.mode;
  if (mode !== 'price' && mode !== 'sac') {
    return errorResponse('invalid_mode', 'mode precisa ser "price" ou "sac"', 400);
  }
  const totalAmount = body.total_amount;
  if (!Number.isInteger(totalAmount) || (totalAmount as number) <= 0) {
    return errorResponse(
      'invalid_total_amount',
      'total_amount precisa ser inteiro positivo (centavos)',
      400,
    );
  }
  const installments = body.installments_total;
  if (!Number.isInteger(installments) || (installments as number) <= 0) {
    return errorResponse(
      'invalid_installments',
      'installments_total precisa ser inteiro positivo',
      400,
    );
  }
  const rate = body.interest_rate_monthly;
  if (typeof rate !== 'number' || rate < 0) {
    return errorResponse(
      'invalid_rate',
      'interest_rate_monthly precisa ser um número não-negativo',
      400,
    );
  }
  const paidPeriods = body.paid_periods ?? 0;
  if (!Number.isInteger(paidPeriods) || (paidPeriods as number) < 0) {
    return errorResponse(
      'invalid_paid_periods',
      'paid_periods precisa ser inteiro não-negativo',
      400,
    );
  }

  const schedule = amortizationSchedule(mode, totalAmount as number, installments as number, rate);

  const remaining = schedule.slice(paidPeriods as number);
  const presentValue = remaining.reduce(
    (sum, row) =>
      sum + Math.round(row.installment / Math.pow(1 + rate, row.period - (paidPeriods as number))),
    0,
  );

  return Response.json({ schedule, early_payoff_present_value: presentValue }, { status: 200 });
}
