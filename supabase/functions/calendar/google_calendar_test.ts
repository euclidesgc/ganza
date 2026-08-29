import { assertEquals, assertRejects } from '@std/assert';
import {
  findEventByProposalId,
  getEvent,
  GoogleCalendarUnavailableError,
  insertEvent,
  listAccessibleCalendars,
  listAllEvents,
} from './google_calendar.ts';

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

function calendarListPage(
  items: { id: string; summary: string }[],
  nextPageToken?: string,
): Response {
  return Response.json({ items, nextPageToken });
}

function eventsPage(items: unknown[], nextPageToken?: string): Response {
  return Response.json({ items, nextPageToken });
}

Deno.test('listAllEvents combina eventos de dois calendários distintos', async () => {
  const { result } = await withFetchStub(
    (call) => {
      if (call.url.includes('/users/me/calendarList')) {
        return calendarListPage([
          { id: 'primary', summary: 'Principal' },
          { id: 'trabalho@group.calendar.google.com', summary: 'Trabalho' },
        ]);
      }
      if (call.url.includes('/calendars/primary/events')) {
        return eventsPage([{
          id: 'ev-1',
          summary: 'Dentista',
          start: { dateTime: '2026-08-28T14:00:00-03:00', timeZone: 'America/Sao_Paulo' },
          end: { dateTime: '2026-08-28T15:00:00-03:00', timeZone: 'America/Sao_Paulo' },
        }]);
      }
      return eventsPage([{
        id: 'ev-2',
        summary: 'Reunião',
        start: { dateTime: '2026-08-29T10:00:00-03:00', timeZone: 'America/Sao_Paulo' },
        end: { dateTime: '2026-08-29T11:00:00-03:00', timeZone: 'America/Sao_Paulo' },
      }]);
    },
    () => listAllEvents(ACCESS_TOKEN, '2026-08-01T00:00:00Z', '2026-09-01T00:00:00Z'),
  );

  assertEquals(result.length, 2);
  assertEquals(result[0].calendar_id, 'primary');
  assertEquals(result[1].calendar_id, 'trabalho@group.calendar.google.com');
});

Deno.test('evento com summary chega normalizado com title igual ao summary do Google', async () => {
  const { result } = await withFetchStub(
    (call) => {
      if (call.url.includes('/users/me/calendarList')) {
        return calendarListPage([{ id: 'primary', summary: 'Principal' }]);
      }
      return eventsPage([{
        id: 'ev-com-titulo',
        summary: 'Dentista',
        start: { dateTime: '2026-08-28T14:00:00-03:00', timeZone: 'America/Sao_Paulo' },
        end: { dateTime: '2026-08-28T15:00:00-03:00', timeZone: 'America/Sao_Paulo' },
      }]);
    },
    () => listAllEvents(ACCESS_TOKEN, '2026-08-01T00:00:00Z', '2026-09-01T00:00:00Z'),
  );

  assertEquals(result.length, 1);
  assertEquals(result[0].title, 'Dentista');
});

Deno.test('evento sem summary chega normalizado com title igual a null', async () => {
  const { result } = await withFetchStub(
    (call) => {
      if (call.url.includes('/users/me/calendarList')) {
        return calendarListPage([{ id: 'primary', summary: 'Principal' }]);
      }
      return eventsPage([{
        id: 'ev-sem-titulo',
        start: { dateTime: '2026-08-28T14:00:00-03:00', timeZone: 'America/Sao_Paulo' },
        end: { dateTime: '2026-08-28T15:00:00-03:00', timeZone: 'America/Sao_Paulo' },
      }]);
    },
    () => listAllEvents(ACCESS_TOKEN, '2026-08-01T00:00:00Z', '2026-09-01T00:00:00Z'),
  );

  assertEquals(result.length, 1);
  assertEquals(result[0].title, null);
});

Deno.test('listAccessibleCalendars segue nextPageToken até esgotar as páginas', async () => {
  const { result, calls } = await withFetchStub(
    (_call, index) => {
      if (index === 0) return calendarListPage([{ id: 'primary', summary: 'Principal' }], 'p2');
      return calendarListPage([{ id: 'trabalho', summary: 'Trabalho' }]);
    },
    () => listAccessibleCalendars(ACCESS_TOKEN),
  );

  assertEquals(result.length, 2);
  assertEquals(calls.length, 2);
  assertEquals(calls[1].url.includes('pageToken=p2'), true);
});

Deno.test('evento de dia inteiro conserva date sem fabricar hora', async () => {
  const { result } = await withFetchStub(
    (call) => {
      if (call.url.includes('/users/me/calendarList')) {
        return calendarListPage([{ id: 'primary', summary: 'Principal' }]);
      }
      return eventsPage([{
        id: 'ev-dia-inteiro',
        summary: 'Feriado',
        start: { date: '2026-09-07' },
        end: { date: '2026-09-08' },
      }]);
    },
    () => listAllEvents(ACCESS_TOKEN, '2026-09-01T00:00:00Z', '2026-10-01T00:00:00Z'),
  );

  assertEquals(result.length, 1);
  assertEquals(result[0].all_day, true);
  assertEquals(result[0].start, '2026-09-07');
  assertEquals(result[0].end, '2026-09-08');
});

Deno.test('uma falha de rede é repetida uma vez antes de devolver sucesso', async () => {
  const { result, calls } = await withFetchStub(
    (_call, index) => {
      if (index === 0) throw new TypeError('network down');
      return calendarListPage([{ id: 'primary', summary: 'Principal' }]);
    },
    () => listAccessibleCalendars(ACCESS_TOKEN),
  );

  assertEquals(calls.length, 2);
  assertEquals(result.length, 1);
});

Deno.test('duas falhas consecutivas declaram Google indisponível', async () => {
  await assertRejects(
    () =>
      withFetchStub(
        () => {
          throw new TypeError('network down');
        },
        () => listAccessibleCalendars(ACCESS_TOKEN),
      ).then(({ result }) => result),
    GoogleCalendarUnavailableError,
  );
});

Deno.test(
  'um calendário indisponível (403) não apaga os eventos do calendário que respondeu',
  async () => {
    const { result } = await withFetchStub(
      (call) => {
        if (call.url.includes('/users/me/calendarList')) {
          return calendarListPage([
            { id: 'primary', summary: 'Principal' },
            { id: 'removido', summary: 'Calendário removido' },
          ]);
        }
        if (call.url.includes('/calendars/removido/events')) {
          return Response.json({ error: 'gone' }, { status: 403 });
        }
        return eventsPage([{
          id: 'ev-1',
          summary: 'Dentista',
          start: { dateTime: '2026-08-28T14:00:00-03:00', timeZone: 'America/Sao_Paulo' },
          end: { dateTime: '2026-08-28T15:00:00-03:00', timeZone: 'America/Sao_Paulo' },
        }]);
      },
      () => listAllEvents(ACCESS_TOKEN, '2026-08-01T00:00:00Z', '2026-09-01T00:00:00Z'),
    );

    assertEquals(result.length, 1);
    assertEquals(result[0].calendar_id, 'primary');
  },
);

Deno.test('todos os calendários indisponíveis ainda propagam o erro', async () => {
  await assertRejects(
    () =>
      withFetchStub(
        (call) => {
          if (call.url.includes('/users/me/calendarList')) {
            return calendarListPage([{ id: 'primary', summary: 'Principal' }]);
          }
          return Response.json({ error: 'gone' }, { status: 403 });
        },
        () => listAllEvents(ACCESS_TOKEN, '2026-08-01T00:00:00Z', '2026-09-01T00:00:00Z'),
      ).then(({ result }) => result),
    GoogleCalendarUnavailableError,
  );
});

Deno.test('findEventByProposalId filtra pela propriedade privada ganza_proposal_id', async () => {
  const { result, calls } = await withFetchStub(
    () =>
      eventsPage([{
        id: 'ev-3',
        start: { dateTime: '2026-08-28T14:00:00-03:00' },
        end: { dateTime: '2026-08-28T15:00:00-03:00' },
      }]),
    () => findEventByProposalId(ACCESS_TOKEN, 'primary', 'proposal-123'),
  );

  assertEquals(result?.id, 'ev-3');
  assertEquals(
    calls[0].url.includes(encodeURIComponent('ganza_proposal_id=proposal-123')),
    true,
  );
});

Deno.test('findEventByProposalId devolve null quando não há evento vinculado', async () => {
  const { result } = await withFetchStub(
    () => eventsPage([]),
    () => findEventByProposalId(ACCESS_TOKEN, 'primary', 'proposal-sem-evento'),
  );

  assertEquals(result, null);
});

Deno.test('getEvent devolve null em 404 sem lançar erro', async () => {
  const { result } = await withFetchStub(
    () => Response.json({ error: 'not found' }, { status: 404 }),
    () => getEvent(ACCESS_TOKEN, 'primary', 'evento-inexistente'),
  );

  assertEquals(result, null);
});

Deno.test('insertEvent envia POST com o corpo do evento ao calendário informado', async () => {
  const { result, calls } = await withFetchStub(
    () =>
      Response.json({
        id: 'ev-criado',
        start: { dateTime: '2026-08-28T14:00:00-03:00' },
        end: { dateTime: '2026-08-28T15:00:00-03:00' },
      }),
    () =>
      insertEvent(ACCESS_TOKEN, 'primary', {
        summary: 'Dentista',
        start: { dateTime: '2026-08-28T14:00:00-03:00', timeZone: 'America/Sao_Paulo' },
        end: { dateTime: '2026-08-28T15:00:00-03:00', timeZone: 'America/Sao_Paulo' },
      }),
  );

  assertEquals(result.id, 'ev-criado');
  assertEquals(calls.length, 1);
  assertEquals(calls[0].method, 'POST');
  assertEquals(calls[0].url.includes('/calendars/primary/events'), true);
  assertEquals((calls[0].body as { summary: string }).summary, 'Dentista');
});
