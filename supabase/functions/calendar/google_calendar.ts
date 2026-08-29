const GOOGLE_CALENDAR_API = 'https://www.googleapis.com/calendar/v3';

// Rede indisponível e resposta 5xx da API convergem para o mesmo tratamento:
// o chamador (calendar_proposals.ts, handler.ts) só precisa saber que a
// escrita/leitura falhou e devolver `google_unavailable`, sem duplicar a
// tentativa em cada ponto de chamada.
export class GoogleCalendarUnavailableError extends Error {}

export interface GoogleCalendarEventTime {
  date?: string;
  dateTime?: string;
  timeZone?: string;
}

export interface GoogleCalendarEvent {
  id: string;
  summary?: string;
  start: GoogleCalendarEventTime;
  end: GoogleCalendarEventTime;
  recurringEventId?: string;
  extendedProperties?: { private?: Record<string, string> };
}

export interface GoogleCalendarListEntry {
  id: string;
  summary: string;
}

export interface NormalizedCalendarEvent {
  calendar_id: string;
  calendar_name: string;
  event_id: string;
  start: string;
  end: string;
  all_day: boolean;
  recurring_event_id: string | null;
  time_zone: string | null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

async function requestOnce(
  url: string,
  accessToken: string,
  init: RequestInit,
): Promise<Response> {
  try {
    return await fetch(url, {
      ...init,
      headers: {
        ...(init.headers ?? {}),
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
    });
  } catch {
    throw new GoogleCalendarUnavailableError(`falha de rede ao chamar ${url}`);
  }
}

// Timeout e instabilidade de rede são comuns o bastante para não virar erro
// definitivo na primeira tentativa: uma única repetição absorve o caso mais
// frequente sem esconder falha persistente do chamador.
async function googleFetch(
  url: string,
  accessToken: string,
  init: RequestInit = {},
): Promise<Response> {
  try {
    const response = await requestOnce(url, accessToken, init);
    if (response.status >= 500) {
      return await requestOnce(url, accessToken, init);
    }
    return response;
  } catch (error) {
    if (error instanceof GoogleCalendarUnavailableError) {
      return await requestOnce(url, accessToken, init);
    }
    throw error;
  }
}

async function listAllPages(
  url: string,
  accessToken: string,
): Promise<Record<string, unknown>[]> {
  const items: Record<string, unknown>[] = [];
  let pageToken: string | undefined;
  do {
    const pageUrl = pageToken ? `${url}&pageToken=${encodeURIComponent(pageToken)}` : url;
    const response = await googleFetch(pageUrl, accessToken);
    if (!response.ok) {
      throw new GoogleCalendarUnavailableError(
        `Google Calendar respondeu ${response.status} em ${url}`,
      );
    }
    const data = await response.json();
    if (!isRecord(data)) {
      throw new GoogleCalendarUnavailableError(`resposta inesperada de ${url}`);
    }
    const pageItems = Array.isArray(data.items) ? data.items : [];
    for (const item of pageItems) {
      if (isRecord(item)) items.push(item);
    }
    pageToken = typeof data.nextPageToken === 'string' ? data.nextPageToken : undefined;
  } while (pageToken);
  return items;
}

function toEventTime(value: Record<string, unknown> | undefined): GoogleCalendarEventTime {
  if (!isRecord(value)) return {};
  return {
    date: typeof value.date === 'string' ? value.date : undefined,
    dateTime: typeof value.dateTime === 'string' ? value.dateTime : undefined,
    timeZone: typeof value.timeZone === 'string' ? value.timeZone : undefined,
  };
}

function toGoogleCalendarEvent(item: Record<string, unknown>): GoogleCalendarEvent {
  return {
    id: typeof item.id === 'string' ? item.id : '',
    summary: typeof item.summary === 'string' ? item.summary : undefined,
    start: toEventTime(item.start as Record<string, unknown> | undefined),
    end: toEventTime(item.end as Record<string, unknown> | undefined),
    recurringEventId: typeof item.recurringEventId === 'string' ? item.recurringEventId : undefined,
    extendedProperties: isRecord(item.extendedProperties)
      ? (item.extendedProperties as GoogleCalendarEvent['extendedProperties'])
      : undefined,
  };
}

function isAllDay(start: GoogleCalendarEventTime): boolean {
  return typeof start.date === 'string' && typeof start.dateTime !== 'string';
}

function normalizeEvent(
  calendarId: string,
  calendarName: string,
  event: GoogleCalendarEvent,
): NormalizedCalendarEvent {
  const allDay = isAllDay(event.start);
  return {
    calendar_id: calendarId,
    calendar_name: calendarName,
    event_id: event.id,
    start: (allDay ? event.start.date : event.start.dateTime) ?? '',
    end: (allDay ? event.end.date : event.end.dateTime) ?? '',
    all_day: allDay,
    recurring_event_id: event.recurringEventId ?? null,
    time_zone: event.start.timeZone ?? null,
  };
}

export async function listAccessibleCalendars(
  accessToken: string,
): Promise<GoogleCalendarListEntry[]> {
  const items = await listAllPages(`${GOOGLE_CALENDAR_API}/users/me/calendarList`, accessToken);
  const entries: GoogleCalendarListEntry[] = [];
  for (const item of items) {
    if (typeof item.id !== 'string' || item.id.length === 0) continue;
    entries.push({
      id: item.id,
      summary: typeof item.summary === 'string' ? item.summary : item.id,
    });
  }
  return entries;
}

export async function listEventsInWindow(
  accessToken: string,
  calendarId: string,
  timeMinIso: string,
  timeMaxIso: string,
): Promise<GoogleCalendarEvent[]> {
  const url = `${GOOGLE_CALENDAR_API}/calendars/${encodeURIComponent(calendarId)}/events` +
    `?singleEvents=true&orderBy=startTime` +
    `&timeMin=${encodeURIComponent(timeMinIso)}&timeMax=${encodeURIComponent(timeMaxIso)}`;
  const items = await listAllPages(url, accessToken);
  return items.map(toGoogleCalendarEvent);
}

export async function listAllEvents(
  accessToken: string,
  timeMinIso: string,
  timeMaxIso: string,
): Promise<NormalizedCalendarEvent[]> {
  const calendars = await listAccessibleCalendars(accessToken);
  const results: NormalizedCalendarEvent[] = [];
  for (const calendar of calendars) {
    const events = await listEventsInWindow(accessToken, calendar.id, timeMinIso, timeMaxIso);
    for (const event of events) {
      results.push(normalizeEvent(calendar.id, calendar.summary, event));
    }
  }
  return results;
}

export async function findEventByProposalId(
  accessToken: string,
  calendarId: string,
  proposalId: string,
): Promise<GoogleCalendarEvent | null> {
  const url = `${GOOGLE_CALENDAR_API}/calendars/${encodeURIComponent(calendarId)}/events` +
    `?privateExtendedProperty=${encodeURIComponent(`ganza_proposal_id=${proposalId}`)}`;
  const items = await listAllPages(url, accessToken);
  const [first] = items;
  return first ? toGoogleCalendarEvent(first) : null;
}

export async function insertEvent(
  accessToken: string,
  calendarId: string,
  body: Record<string, unknown>,
): Promise<GoogleCalendarEvent> {
  const response = await googleFetch(
    `${GOOGLE_CALENDAR_API}/calendars/${encodeURIComponent(calendarId)}/events`,
    accessToken,
    { method: 'POST', body: JSON.stringify(body) },
  );
  if (!response.ok) {
    throw new GoogleCalendarUnavailableError(
      `Google Calendar respondeu ${response.status} ao criar evento`,
    );
  }
  const data = await response.json();
  if (!isRecord(data)) {
    throw new GoogleCalendarUnavailableError('resposta inesperada ao criar evento');
  }
  return toGoogleCalendarEvent(data);
}

export async function getEvent(
  accessToken: string,
  calendarId: string,
  eventId: string,
): Promise<GoogleCalendarEvent | null> {
  const response = await googleFetch(
    `${GOOGLE_CALENDAR_API}/calendars/${encodeURIComponent(calendarId)}/events/${
      encodeURIComponent(eventId)
    }`,
    accessToken,
  );
  if (response.status === 404) return null;
  if (!response.ok) {
    throw new GoogleCalendarUnavailableError(
      `Google Calendar respondeu ${response.status} ao ler evento`,
    );
  }
  const data = await response.json();
  if (!isRecord(data)) {
    throw new GoogleCalendarUnavailableError('resposta inesperada ao ler evento');
  }
  return toGoogleCalendarEvent(data);
}

export async function patchEvent(
  accessToken: string,
  calendarId: string,
  eventId: string,
  body: Record<string, unknown>,
): Promise<GoogleCalendarEvent> {
  const response = await googleFetch(
    `${GOOGLE_CALENDAR_API}/calendars/${encodeURIComponent(calendarId)}/events/${
      encodeURIComponent(eventId)
    }`,
    accessToken,
    { method: 'PATCH', body: JSON.stringify(body) },
  );
  if (!response.ok) {
    throw new GoogleCalendarUnavailableError(
      `Google Calendar respondeu ${response.status} ao remarcar evento`,
    );
  }
  const data = await response.json();
  if (!isRecord(data)) {
    throw new GoogleCalendarUnavailableError('resposta inesperada ao remarcar evento');
  }
  return toGoogleCalendarEvent(data);
}
