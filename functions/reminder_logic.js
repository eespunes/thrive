'use strict';

const { DateTime } = require('luxon');

const DAY_MS = 86_400_000;
const HORIZON_DAYS = 30;
const OFFSETS = { at: 0, '5m': 300_000, '15m': 900_000, '30m': 1_800_000, '1h': 3_600_000, '2h': 7_200_000, '1d': DAY_MS, '2d': 2 * DAY_MS };
const date = (iso) => DateTime.fromISO(String(iso || ''), { zone: 'UTC' });
const iso = (d) => d.toISODate();
const weekday = (d) => d.weekday;
const monthDistance = (a, b) => (b.year - a.year) * 12 + b.month - a.month;
const weekDistance = (a, b) => Math.floor(b.startOf('week').diff(a.startOf('week'), 'days').days / 7);

function nthWeekday(year, month, nth, day) {
  const first = DateTime.utc(year, month, 1);
  if (nth === 5) {
    const last = first.endOf('month');
    return last.minus({ days: (last.weekday - day + 7) % 7 }).day;
  }
  return 1 + (day - first.weekday + 7) % 7 + (nth - 1) * 7;
}

function occursOn(ev, occurrence) {
  const start = date(ev.date);
  const day = date(occurrence);
  if (!start.isValid || !day.isValid || day < start || (ev.endDate && occurrence > ev.endDate)) return false;
  if ((ev.exceptions || []).includes(occurrence)) return false;
  const diff = Math.round(day.diff(start, 'days').days);
  const recur = ev.recur || 'none';
  if (recur === 'none') return diff === 0;
  if (recur === 'daily') return true;
  if (recur === 'weekly') return diff % 7 === 0;
  if (recur === 'monthly' && ev.monthlyMode === 'nthWeekday') {
    const nth = Number(ev.monthlyNth || 1);
    const wd = Number(ev.monthlyWeekday || 1);
    return day.day === nthWeekday(day.year, day.month, nth, wd);
  }
  if (recur === 'monthly') return day.day === Math.min(start.day, day.daysInMonth);
  if (recur === 'yearly') return day.month === start.month && day.day === Math.min(start.day, day.daysInMonth);
  if (recur !== 'custom') return false;
  const every = Math.max(1, Number(ev.recurEvery || 1));
  switch (ev.recurUnit || 'week') {
    case 'day': return diff % every === 0;
    case 'month': return monthDistance(start, day) % every === 0 && day.day === Math.min(start.day, day.daysInMonth);
    case 'year': return (day.year - start.year) % every === 0 && day.month === start.month && day.day === Math.min(start.day, day.daysInMonth);
    default: {
      const days = Array.isArray(ev.recurWeekdays) && ev.recurWeekdays.length ? ev.recurWeekdays : [weekday(start)];
      return weekDistance(start, day) % every === 0 && days.includes(weekday(day));
    }
  }
}

function occurrenceDates(ev, from, through) {
  const a = date(from), b = date(through);
  if (!a.isValid || !b.isValid) return [];
  const out = [];
  for (let d = a; d <= b; d = d.plus({ days: 1 })) {
    if (occursOn(ev, iso(d))) out.push(iso(d));
  }
  return out;
}

function startAt(ev, occurrence, zone) {
  const time = !ev.allDay && /^\d\d:\d\d$/.test(ev.start || '') ? ev.start : '09:00';
  const dt = DateTime.fromISO(`${occurrence}T${time}`, { zone });
  return dt.isValid ? dt.toMillis() : null;
}

function dueAt(ev, occurrence, kind, zone) {
  if (!occursOn(ev, occurrence)) return null;
  const start = startAt(ev, occurrence, zone);
  if (start === null) return null;
  if (kind === 'start') return ev.reminder === 'at' ? null : start;
  if (kind !== 'reminder' || !Object.hasOwn(OFFSETS, ev.reminder)) return null;
  return start - OFFSETS[ev.reminder];
}

function reminderBody(ev) {
  const t = !ev.allDay && ev.start ? ev.start : '';
  const r = ev.reminder;
  let body;
  if (r === 'at') body = ev.allDay ? 'All day today' : t ? `Starting at ${t}` : 'Starting now';
  else if (r === '1h') body = t ? `Starts in 1 hour · ${t}` : 'Starts in 1 hour';
  else if (r === '1d') body = t ? `Starts tomorrow · ${t}` : 'Starts tomorrow';
  else {
    const amount = Number(r.slice(0, -1));
    const unit = r.slice(-1);
    const label = unit === 'm' ? `Starts in ${amount} minute${amount === 1 ? '' : 's'}`
      : unit === 'h' ? `Starts in ${amount} hour${amount === 1 ? '' : 's'}`
        : amount === 1 ? 'Starts tomorrow' : `Starts in ${amount} days`;
    body = t ? `${label} · ${t}` : label;
  }
  return ev.location ? `${body} – ${ev.location}` : body;
}

function startCopy(ev, names) {
  if (ev.allDay || !ev.start) return { title: `${ev.title} is today`, body: ev.location || '' };
  const time = ev.end ? `${ev.start}–${ev.end}` : ev.start;
  return {
    title: names ? `${ev.title} · ${names} starts now` : `${ev.title} starts now`,
    body: ev.location ? `${time} – ${ev.location}` : time,
  };
}

module.exports = { DAY_MS, HORIZON_DAYS, occursOn, occurrenceDates, dueAt, reminderBody, startCopy };
