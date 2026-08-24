export type AmortizationMode = 'price' | 'sac';

export interface ScheduleRow {
  period: number;
  installment: number;
  interest: number;
  principal: number;
  balance: number;
}

// PMT = PV · i / (1 − (1+i)⁻ⁿ). Dinheiro é centavo inteiro: o arredondamento
// é explícito (Math.round) uma vez por cálculo, nunca um número fracionário.
export function priceInstallment(
  totalCents: number,
  months: number,
  monthlyRate: number,
): number {
  if (months <= 0) return 0;
  if (monthlyRate === 0) return Math.round(totalCents / months);
  const factor = Math.pow(1 + monthlyRate, -months);
  return Math.round((totalCents * monthlyRate) / (1 - factor));
}

export function amortizationSchedule(
  mode: AmortizationMode,
  totalCents: number,
  months: number,
  monthlyRate: number,
): ScheduleRow[] {
  const rows: ScheduleRow[] = [];

  if (mode === 'price') {
    const fixed = priceInstallment(totalCents, months, monthlyRate);
    let balance = totalCents;
    for (let period = 1; period <= months; period++) {
      const interest = Math.round(balance * monthlyRate);
      const principal = period === months ? balance : fixed - interest;
      balance -= principal;
      rows.push({ period, installment: principal + interest, interest, principal, balance });
    }
    return rows;
  }

  const principalFixed = Math.round(totalCents / months);
  let remaining = totalCents;
  for (let period = 1; period <= months; period++) {
    const interest = Math.round(remaining * monthlyRate);
    const principal = period === months ? remaining : principalFixed;
    remaining -= principal;
    rows.push({
      period,
      installment: principal + interest,
      interest,
      principal,
      balance: remaining,
    });
  }
  return rows;
}

// Valor presente das parcelas restantes descontado pela taxa do contrato — o
// que o CDC manda para a liquidação antecipada.
export function earlyPayoffPresentValue(
  installmentCents: number,
  remainingMonths: number,
  monthlyRate: number,
): number {
  if (remainingMonths <= 0) return 0;
  if (monthlyRate === 0) return installmentCents * remainingMonths;
  const factor = Math.pow(1 + monthlyRate, -remainingMonths);
  return Math.round((installmentCents * (1 - factor)) / monthlyRate);
}
