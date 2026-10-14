'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const R = require('../reminder_logic');

const event = { id: 'e', title: 'Swim', date: '2026-10-14', start: '14:30', reminder: '1h', recur: 'none' };

test('cloud due time follows the recipient timezone and reminder offset', () => {
  assert.equal(R.dueAt(event, '2026-10-14', 'reminder', 'Europe/Amsterdam'), Date.parse('2026-10-14T11:30:00Z'));
  assert.equal(R.dueAt(event, '2026-10-14', 'reminder', 'America/New_York'), Date.parse('2026-10-14T17:30:00Z'));
  assert.equal(R.dueAt({ ...event, reminder: 'at' }, '2026-10-14', 'start', 'Europe/Amsterdam'), null);
  assert.equal(R.dueAt({ ...event, allDay: true }, '2026-10-14', 'start', 'Europe/Amsterdam'), Date.parse('2026-10-14T07:00:00Z'));
});

test('recurring dates include monthly clamp, nth weekday, custom week and exceptions', () => {
  assert.deepEqual(R.occurrenceDates({ ...event, date: '2026-01-31', recur: 'monthly' }, '2026-02-01', '2026-03-31'), ['2026-02-28', '2026-03-31']);
  assert.deepEqual(R.occurrenceDates({ ...event, date: '2026-10-01', recur: 'monthly', monthlyMode: 'nthWeekday', monthlyNth: 5, monthlyWeekday: 5 }, '2026-10-01', '2026-11-30'), ['2026-10-30', '2026-11-27']);
  assert.deepEqual(R.occurrenceDates({ ...event, recur: 'custom', recurUnit: 'week', recurEvery: 2, recurWeekdays: [3], exceptions: ['2026-10-28'] }, '2026-10-14', '2026-11-12'), ['2026-10-14', '2026-11-11']);
});

test('spring daylight saving uses the later local clock offset', () => {
  const e = { ...event, date: '2027-03-28', start: '09:00' };
  assert.equal(R.dueAt(e, e.date, 'reminder', 'Europe/Amsterdam'), Date.parse('2027-03-28T06:00:00Z'));
});
