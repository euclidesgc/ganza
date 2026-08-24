import { assertEquals } from '@std/assert';
import { amortizationSchedule, earlyPayoffPresentValue, priceInstallment } from './finance_math.ts';

Deno.test('priceInstallment é centavo inteiro positivo', () => {
  const parcela = priceInstallment(6_000_000, 48, 0.012);
  assertEquals(Number.isInteger(parcela), true);
  assertEquals(parcela > 0, true);
});

Deno.test('amortização Price: saldo final zero e principal soma o total', () => {
  const total = 6_000_000;
  const rows = amortizationSchedule('price', total, 48, 0.012);
  assertEquals(rows.length, 48);
  assertEquals(rows[47].balance, 0);
  const principalTotal = rows.reduce((sum, row) => sum + row.principal, 0);
  assertEquals(Math.abs(principalTotal - total) <= 48, true);
});

Deno.test('amortização SAC: principal constante e saldo final zero', () => {
  const total = 6_000_000;
  const rows = amortizationSchedule('sac', total, 48, 0.012);
  assertEquals(rows.length, 48);
  assertEquals(rows[47].balance, 0);
  const fixed = Math.round(total / 48);
  for (let i = 0; i < 47; i++) {
    assertEquals(rows[i].principal, fixed);
  }
});

Deno.test('quitação antecipada desconta as parcelas restantes', () => {
  const parcela = priceInstallment(6_000_000, 48, 0.012);
  const pv = earlyPayoffPresentValue(parcela, 48, 0.012);
  assertEquals(pv < parcela * 48, true);
  assertEquals(Number.isInteger(pv), true);
});

Deno.test('taxa zero: parcela é total dividido e PV é a soma nominal', () => {
  assertEquals(priceInstallment(120_000, 12, 0), 10_000);
  assertEquals(earlyPayoffPresentValue(10_000, 12, 0), 120_000);
});
