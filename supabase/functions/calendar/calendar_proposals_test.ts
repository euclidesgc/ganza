import { assertEquals } from '@std/assert';
import { cancelCalendarProposal, confirmCalendarProposal } from './calendar_proposals.ts';

const ACCESS_TOKEN = 'access-token-de-teste';

interface FetchCall {
  url: string;
  method: string;
  body: unknown;
}

async function withFetchStub<T>(
  responder: (call: FetchCall, callIndex: number) => Response,
  run: () => Promise<T>,
): Promise<{ result: T; calls: FetchCall[] }> {
  const original = globalThis.fetch;
  const calls: FetchCall[] = [];
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    const call: FetchCall = {
      url: typeof input === 'string' ? input : input.toString(),
      method: init?.method ?? 'GET',
      body: init?.body ? JSON.parse(init.body as string) : undefined,
    };
    const index = calls.length;
    calls.push(call);
    return Promise.resolve().then(() => responder(call, index));
  }) as typeof fetch;

  try {
    const result = await run();
    return { result, calls };
  } finally {
    globalThis.fetch = original;
  }
}

interface ChainResult {
  data?: unknown;
  error?: unknown;
}

function fakeSupabase(row: Record<string, unknown> | null) {
  let current = row;
  const updates: Record<string, unknown>[] = [];

  function chain(result: ChainResult) {
    const node = {
      eq: () => node,
      select: () => node,
      maybeSingle: () => Promise.resolve(result),
      then: (resolve: (value: ChainResult) => void, reject?: (reason: unknown) => void) => {
        Promise.resolve(result).then(resolve, reject);
      },
    };
    return node;
  }

  const supabase = {
    from: (table: string) => ({
      select: () => chain({ data: current, error: null }),
      update: (patch: Record<string, unknown>) => {
        updates.push({ table, patch });
        if (current) current = { ...current, ...patch };
        return chain({ error: null });
      },
    }),
  };

  return { supabase, updates, currentRow: () => current };
}

function createProposalRow(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: 'prop-1',
    status: 'pending',
    kind: 'create_calendar_event',
    payload: {
      title: 'Dentista',
      calendar_id: 'primary',
      time_zone: 'America/Sao_Paulo',
      start: '2026-08-28T14:00:00-03:00',
      end: '2026-08-28T15:00:00-03:00',
      all_day: false,
    },
    ...overrides,
  };
}

function rescheduleProposalRow(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: 'prop-2',
    status: 'pending',
    kind: 'reschedule_calendar_event',
    payload: {
      calendar_id: 'primary',
      event_id: 'ev-9',
      time_zone: 'America/Sao_Paulo',
      start: '2026-08-28T16:00:00-03:00',
      end: '2026-08-28T17:00:00-03:00',
      all_day: false,
      original_start: '2026-08-28T14:00:00-03:00',
      original_end: '2026-08-28T15:00:00-03:00',
    },
    ...overrides,
  };
}

function eventResponse(body: Record<string, unknown>): Response {
  return Response.json(body);
}

Deno.test('confirmar cria evento com ganza_proposal_id igual ao id da proposta e lista antes de criar', async () => {
  const { supabase, updates } = fakeSupabase(createProposalRow());

  const { result, calls } = await withFetchStub(
    (_call, index) => {
      if (index === 0) return eventResponse({ items: [] });
      return eventResponse({ id: 'ev-created', start: {}, end: {} });
    },
    () => confirmCalendarProposal(supabase, ACCESS_TOKEN, 'prop-1'),
  );

  assertEquals(result.ok, true);
  assertEquals(calls.length, 2);
  assertEquals(calls[0].method, 'GET');
  assertEquals(calls[0].url.includes(encodeURIComponent('ganza_proposal_id=prop-1')), true);
  assertEquals(calls[1].method, 'POST');
  const body = calls[1].body as { extendedProperties: { private: { ganza_proposal_id: string } } };
  assertEquals(body.extendedProperties.private.ganza_proposal_id, 'prop-1');
  assertEquals(updates[0].patch, {
    status: 'confirmed',
    resulting_id: 'ev-created',
    resulting_type: 'calendar_event',
  });
});

Deno.test('retry de ganza_proposal_id encontra evento existente e não duplica no Google', async () => {
  const { supabase } = fakeSupabase(createProposalRow());

  const { result, calls } = await withFetchStub(
    () =>
      eventResponse({
        items: [{ id: 'ev-ja-criado', start: {}, end: {} }],
      }),
    () => confirmCalendarProposal(supabase, ACCESS_TOKEN, 'prop-1'),
  );

  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.eventId, 'ev-ja-criado');
  assertEquals(calls.length, 1);
  assertEquals(calls.some((call) => call.method === 'POST'), false);
});

Deno.test('remarcação relê o evento e faz PATCH quando start e end batem com o original', async () => {
  const { supabase, updates } = fakeSupabase(rescheduleProposalRow());

  const { result, calls } = await withFetchStub(
    (_call, index) => {
      if (index === 0) {
        return eventResponse({
          id: 'ev-9',
          start: { dateTime: '2026-08-28T14:00:00-03:00' },
          end: { dateTime: '2026-08-28T15:00:00-03:00' },
        });
      }
      return eventResponse({
        id: 'ev-9',
        start: { dateTime: '2026-08-28T16:00:00-03:00' },
        end: { dateTime: '2026-08-28T17:00:00-03:00' },
      });
    },
    () => confirmCalendarProposal(supabase, ACCESS_TOKEN, 'prop-2'),
  );

  assertEquals(result.ok, true);
  assertEquals(calls.length, 2);
  assertEquals(calls[0].method, 'GET');
  assertEquals(calls[1].method, 'PATCH');
  assertEquals(updates[0].patch, {
    status: 'confirmed',
    resulting_id: 'ev-9',
    resulting_type: 'calendar_event',
  });
});

Deno.test('remarcação não faz PATCH quando a releitura devolve 404 e responde event_not_found', async () => {
  const { supabase } = fakeSupabase(rescheduleProposalRow());

  const { result, calls } = await withFetchStub(
    () => Response.json({ error: 'not found' }, { status: 404 }),
    () => confirmCalendarProposal(supabase, ACCESS_TOKEN, 'prop-2'),
  );

  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'event_not_found');
  assertEquals(calls.length, 1);
  assertEquals(calls.some((call) => call.method === 'PATCH'), false);
});

Deno.test('remarcação não faz PATCH quando start ou end divergem do original e responde event_ambiguous', async () => {
  const { supabase } = fakeSupabase(rescheduleProposalRow());

  const { result, calls } = await withFetchStub(
    () =>
      eventResponse({
        id: 'ev-9',
        start: { dateTime: '2026-08-28T18:00:00-03:00' },
        end: { dateTime: '2026-08-28T19:00:00-03:00' },
      }),
    () => confirmCalendarProposal(supabase, ACCESS_TOKEN, 'prop-2'),
  );

  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'event_ambiguous');
  assertEquals(calls.length, 1);
  assertEquals(calls.some((call) => call.method === 'PATCH'), false);
});

Deno.test('remarcação não faz PATCH quando o evento tem recurringEventId e responde recurring_event_unsupported', async () => {
  const { supabase } = fakeSupabase(rescheduleProposalRow());

  const { result, calls } = await withFetchStub(
    () =>
      eventResponse({
        id: 'ev-9',
        start: { dateTime: '2026-08-28T14:00:00-03:00' },
        end: { dateTime: '2026-08-28T15:00:00-03:00' },
        recurringEventId: 'serie-1',
      }),
    () => confirmCalendarProposal(supabase, ACCESS_TOKEN, 'prop-2'),
  );

  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'recurring_event_unsupported');
  assertEquals(calls.length, 1);
  assertEquals(calls.some((call) => call.method === 'PATCH'), false);
});

Deno.test('cancelar uma proposta pendente não chama fetch do Google', async () => {
  const { supabase, updates } = fakeSupabase(createProposalRow());

  const { result, calls } = await withFetchStub(
    () => {
      throw new Error('Cancelar não deveria chamar a rede');
    },
    () => cancelCalendarProposal(supabase, 'prop-1'),
  );

  assertEquals(result.ok, true);
  if (result.ok) assertEquals(result.status, 'cancelled');
  assertEquals(calls.length, 0);
  assertEquals(updates[0].patch, { status: 'cancelled' });
});

Deno.test('confirmar proposta inexistente devolve proposal_not_found sem chamar fetch', async () => {
  const { supabase } = fakeSupabase(null);

  const { result, calls } = await withFetchStub(
    () => {
      throw new Error('não deveria chamar a rede');
    },
    () => confirmCalendarProposal(supabase, ACCESS_TOKEN, 'prop-inexistente'),
  );

  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'proposal_not_found');
  assertEquals(calls.length, 0);
});

Deno.test('confirmar proposta já confirmada devolve proposal_not_pending sem chamar fetch', async () => {
  const { supabase } = fakeSupabase(createProposalRow({ status: 'confirmed' }));

  const { result, calls } = await withFetchStub(
    () => {
      throw new Error('não deveria chamar a rede');
    },
    () => confirmCalendarProposal(supabase, ACCESS_TOKEN, 'prop-1'),
  );

  assertEquals(result.ok, false);
  if (!result.ok) assertEquals(result.code, 'proposal_not_pending');
  assertEquals(calls.length, 0);
});
