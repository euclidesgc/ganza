import { assertEquals } from '@std/assert';
import handler from './handler.ts';

function requestCom(body: unknown, method = 'POST'): Request {
  return new Request('http://localhost/functions/v1/finance-math', {
    method,
    headers: {
      'Authorization': 'Bearer token-do-usuario',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

const VALIDO = {
  mode: 'price',
  total_amount: 6_000_000,
  installments_total: 48,
  interest_rate_monthly: 0.012,
};

Deno.test('método errado devolve 405', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/finance-math', { method: 'GET' }),
  );
  assertEquals(response.status, 405);
});

Deno.test('sem Authorization devolve 401', async () => {
  const response = await handler(
    new Request('http://localhost/functions/v1/finance-math', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(VALIDO),
    }),
  );
  assertEquals(response.status, 401);
});

Deno.test('mode inválido devolve 400', async () => {
  const response = await handler(requestCom({ ...VALIDO, mode: 'misto' }));
  assertEquals(response.status, 400);
});

Deno.test('total_amount inválido devolve 400', async () => {
  const response = await handler(requestCom({ ...VALIDO, total_amount: 0 }));
  assertEquals(response.status, 400);
});

Deno.test('installments_total inválido devolve 400', async () => {
  const response = await handler(requestCom({ ...VALIDO, installments_total: -1 }));
  assertEquals(response.status, 400);
});

Deno.test('taxa negativa devolve 400', async () => {
  const response = await handler(
    requestCom({ ...VALIDO, interest_rate_monthly: -0.01 }),
  );
  assertEquals(response.status, 400);
});

Deno.test('caminho feliz devolve o cronograma e o valor presente', async () => {
  const response = await handler(requestCom(VALIDO));
  assertEquals(response.status, 200);
  const corpo = await response.json() as {
    schedule: Array<{ period: number; balance: number }>;
    early_payoff_present_value: number;
  };
  assertEquals(corpo.schedule.length, 48);
  assertEquals(corpo.schedule[47].balance, 0);
  assertEquals(Number.isInteger(corpo.early_payoff_present_value), true);
});

Deno.test('paid_periods reduz o valor presente da quitação', async () => {
  const semPago = await handler(requestCom(VALIDO));
  const comPago = await handler(requestCom({ ...VALIDO, paid_periods: 24 }));
  const pvSem = ((await semPago.json()) as { early_payoff_present_value: number })
    .early_payoff_present_value;
  const pvCom = ((await comPago.json()) as { early_payoff_present_value: number })
    .early_payoff_present_value;
  assertEquals(pvCom < pvSem, true);
});
