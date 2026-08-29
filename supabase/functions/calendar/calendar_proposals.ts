import {
  findEventByProposalId,
  getEvent,
  GoogleCalendarUnavailableError,
  insertEvent,
  patchEvent,
} from './google_calendar.ts';
import type { GoogleCalendarEventTime } from './google_calendar.ts';

export type CalendarProposalResult =
  | { ok: true; status: 'confirmed' | 'cancelled'; proposalId: string; eventId?: string }
  | { ok: false; code: string };

interface CreateCalendarEventPayload {
  title: string;
  calendarId: string;
  timeZone: string;
  start: string;
  end: string;
  allDay: boolean;
}

interface RescheduleCalendarEventPayload {
  calendarId: string;
  eventId: string;
  timeZone: string;
  start: string;
  end: string;
  allDay: boolean;
  originalStart: string;
  originalEnd: string;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function parseCreatePayload(payload: Record<string, unknown>): CreateCalendarEventPayload | null {
  if (
    !isNonEmptyString(payload.title) ||
    !isNonEmptyString(payload.calendar_id) ||
    !isNonEmptyString(payload.time_zone) ||
    !isNonEmptyString(payload.start) ||
    !isNonEmptyString(payload.end) ||
    typeof payload.all_day !== 'boolean'
  ) {
    return null;
  }
  return {
    title: payload.title,
    calendarId: payload.calendar_id,
    timeZone: payload.time_zone,
    start: payload.start,
    end: payload.end,
    allDay: payload.all_day,
  };
}

function parseReschedulePayload(
  payload: Record<string, unknown>,
): RescheduleCalendarEventPayload | null {
  if (
    !isNonEmptyString(payload.calendar_id) ||
    !isNonEmptyString(payload.event_id) ||
    !isNonEmptyString(payload.time_zone) ||
    !isNonEmptyString(payload.start) ||
    !isNonEmptyString(payload.end) ||
    typeof payload.all_day !== 'boolean' ||
    !isNonEmptyString(payload.original_start) ||
    !isNonEmptyString(payload.original_end)
  ) {
    return null;
  }
  return {
    calendarId: payload.calendar_id,
    eventId: payload.event_id,
    timeZone: payload.time_zone,
    start: payload.start,
    end: payload.end,
    allDay: payload.all_day,
    originalStart: payload.original_start,
    originalEnd: payload.original_end,
  };
}

function toGoogleEventTime(
  iso: string,
  allDay: boolean,
  timeZone: string,
): GoogleCalendarEventTime {
  return allDay ? { date: iso } : { dateTime: iso, timeZone };
}

function readEventInstant(time: GoogleCalendarEventTime): string | null {
  return time.dateTime ?? time.date ?? null;
}

async function finalizeConfirmation(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  proposalId: string,
  eventId: string,
): Promise<CalendarProposalResult> {
  // Transição condicional: só avança quem ainda está `pending`, para que uma
  // segunda chamada concorrente não sobrescreva o resultado da primeira.
  const { error } = await supabase
    .from('proposed_actions')
    .update({ status: 'confirmed', resulting_id: eventId, resulting_type: 'calendar_event' })
    .eq('id', proposalId)
    .eq('status', 'pending');
  if (error) {
    return { ok: false, code: 'write_failed' };
  }
  return { ok: true, status: 'confirmed', proposalId, eventId };
}

async function confirmCreate(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  accessToken: string,
  proposalId: string,
  payload: CreateCalendarEventPayload,
): Promise<CalendarProposalResult> {
  const existing = await findEventByProposalId(accessToken, payload.calendarId, proposalId);
  const event = existing ?? await insertEvent(accessToken, payload.calendarId, {
    summary: payload.title,
    start: toGoogleEventTime(payload.start, payload.allDay, payload.timeZone),
    end: toGoogleEventTime(payload.end, payload.allDay, payload.timeZone),
    extendedProperties: { private: { ganza_proposal_id: proposalId } },
  });
  return finalizeConfirmation(supabase, proposalId, event.id);
}

async function confirmReschedule(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  accessToken: string,
  proposalId: string,
  payload: RescheduleCalendarEventPayload,
): Promise<CalendarProposalResult> {
  const event = await getEvent(accessToken, payload.calendarId, payload.eventId);
  if (event === null) {
    return { ok: false, code: 'event_not_found' };
  }
  // FD-005: recusa tanto a ocorrência de uma série (`recurringEventId`)
  // quanto o evento-mestre (`recurrence` preenchido) — os dois nunca
  // coexistem no mesmo evento, e o mestre não carrega `recurringEventId`.
  if (isNonEmptyString(event.recurringEventId) || (event.recurrence?.length ?? 0) > 0) {
    return { ok: false, code: 'recurring_event_unsupported' };
  }
  if (
    readEventInstant(event.start) !== payload.originalStart ||
    readEventInstant(event.end) !== payload.originalEnd
  ) {
    return { ok: false, code: 'event_ambiguous' };
  }

  const patched = await patchEvent(accessToken, payload.calendarId, payload.eventId, {
    start: toGoogleEventTime(payload.start, payload.allDay, payload.timeZone),
    end: toGoogleEventTime(payload.end, payload.allDay, payload.timeZone),
  });
  return finalizeConfirmation(supabase, proposalId, patched.id);
}

export async function confirmCalendarProposal(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  accessToken: string,
  proposalId: string,
): Promise<CalendarProposalResult> {
  const { data, error } = await supabase
    .from('proposed_actions')
    .select('*')
    .eq('id', proposalId)
    .maybeSingle();
  if (error || !data) {
    return { ok: false, code: 'proposal_not_found' };
  }
  if (data.status !== 'pending') {
    return { ok: false, code: 'proposal_not_pending' };
  }
  if (data.kind !== 'create_calendar_event' && data.kind !== 'reschedule_calendar_event') {
    return { ok: false, code: 'invalid_payload' };
  }
  if (typeof data.payload !== 'object' || data.payload === null) {
    return { ok: false, code: 'invalid_payload' };
  }
  const payloadRecord = data.payload as Record<string, unknown>;

  try {
    if (data.kind === 'create_calendar_event') {
      const payload = parseCreatePayload(payloadRecord);
      if (!payload) return { ok: false, code: 'invalid_payload' };
      return await confirmCreate(supabase, accessToken, proposalId, payload);
    }
    const payload = parseReschedulePayload(payloadRecord);
    if (!payload) return { ok: false, code: 'invalid_payload' };
    return await confirmReschedule(supabase, accessToken, proposalId, payload);
  } catch (err) {
    if (err instanceof GoogleCalendarUnavailableError) {
      return { ok: false, code: 'google_unavailable' };
    }
    throw err;
  }
}

export async function cancelCalendarProposal(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  proposalId: string,
): Promise<CalendarProposalResult> {
  const { data, error } = await supabase
    .from('proposed_actions')
    .select('id, status, kind')
    .eq('id', proposalId)
    .maybeSingle();
  if (error || !data) {
    return { ok: false, code: 'proposal_not_found' };
  }
  if (data.status !== 'pending') {
    return { ok: false, code: 'proposal_not_pending' };
  }

  const { error: updateError } = await supabase
    .from('proposed_actions')
    .update({ status: 'cancelled' })
    .eq('id', proposalId)
    .eq('status', 'pending');
  if (updateError) {
    return { ok: false, code: 'write_failed' };
  }
  return { ok: true, status: 'cancelled', proposalId };
}
