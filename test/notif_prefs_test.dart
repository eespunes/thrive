// The notification-choices model (#473/#484/#485).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_money_management_app/main.dart';

void main() {
  group('defaults (§3)', () {
    test('adults follow their kids and shared money', () {
      final p = NotifPrefs.defaults(selfId: 'me', kidIds: ['k']);
      expect(p.type('chores').scope, 'kids');
      expect(p.type('chores').pick, ['k']);
      expect(p.type('cal').pick, ['me', 'k']);
      expect(p.type('money').scope, 'shared');
      expect(p.type('wall').on, isFalse);
      expect(p.type('chores').eventsOn, 2);
      expect(p.quiet.summary, '21:30–07:00 · every day');
    });

    test('kids follow only themselves', () {
      final p = NotifPrefs.defaults(kid: true, selfId: 'k');
      expect(p.type('chores').scope, 'me');
      expect(p.type('cal').pick, ['k']);
      expect(p.type('money').scope, 'pick');
      expect(p.type('money').pick, ['k']);
      expect(NotifPrefs.defaults().type('cal').pick, isEmpty);
    });
  });

  group('fromJson', () {
    final base = NotifPrefs.defaults(selfId: 'me');

    test('non-maps keep the fallback', () {
      expect(NotifPrefs.fromJson(null, base).toJson(), base.toJson());
      expect(
        NotifPrefs.fromJson({'chores': 'x', 'quiet': 3}, base).toJson(),
        base.toJson(),
      );
    });

    test('reads valid fields and ignores bad ones', () {
      final p = NotifPrefs.fromJson({
        'chores': {
          'on': false,
          'scope': 'nope',
          'pick': ['a', 2],
          'events': {'done': false, 'bogus': true, 'reward': 'yes'},
        },
        'lists': {'scope': 'mine'},
        'quiet': {
          'on': false,
          'from': '22:00',
          'to': '25:00',
          'days': [true, false, true, false, true, false, true],
          'letReminders': false,
        },
      }, base);
      final c = p.type('chores');
      expect(c.on, isFalse);
      expect(c.scope, 'kids');
      expect(c.pick, ['a', '2']);
      expect(c.events, {'done': false, 'reward': true, 'stars': false});
      expect(p.type('lists').scope, 'mine');
      expect(p.quiet.on, isFalse);
      expect(p.quiet.from, '22:00');
      expect(p.quiet.to, '07:00');
      expect(p.quiet.days.where((d) => d).length, 4);
      expect(p.quiet.letReminders, isFalse);
      // Bad day lists are ignored.
      expect(
        NotifPrefs.fromJson({
          'quiet': {
            'days': [true],
            'from': 'x',
            'to': '7:aa',
          },
        }, base).quiet.days.length,
        7,
      );
    });

    test('every event unticked turns the type off', () {
      final p = NotifPrefs.fromJson({
        'family': {
          'on': true,
          'events': {'joined': false, 'left': false, 'role': false},
        },
      }, base);
      expect(p.type('family').on, isFalse);
    });

    test('round-trips through JSON and copies deeply', () {
      final p = base.copy()..type('money').pick.add('x');
      expect(base.type('money').pick, isEmpty);
      expect(NotifPrefs.fromJson(p.toJson(), base).toJson(), p.toJson());
    });
  });

  group('quiet hours', () {
    DateTime at(int weekday, int h, int m) =>
        DateTime(2026, 6, weekday, h, m); // 2026-06-01 is a Monday

    test('overnight windows belong to the evening they start', () {
      final q = NotifQuietPrefs();
      expect(q.covers(at(1, 21, 29)), isFalse);
      expect(q.covers(at(1, 21, 30)), isTrue);
      expect(q.covers(at(2, 6, 59)), isTrue);
      expect(q.covers(at(2, 7, 0)), isFalse);
      expect(q.covers(at(2, 12, 0)), isFalse);
      q.days = [false, true, true, true, true, true, true]; // no Monday
      expect(q.covers(at(1, 22, 0)), isFalse);
      expect(q.covers(at(2, 6, 0)), isFalse); // Monday's night
      expect(q.covers(at(1, 6, 0)), isTrue); // Sunday's night
    });

    test('same-day windows, off and invalid times', () {
      final q = NotifQuietPrefs(from: '13:00', to: '15:00');
      expect(q.covers(at(3, 14, 0)), isTrue);
      expect(q.covers(at(3, 15, 0)), isFalse);
      q.days[2] = false;
      expect(q.covers(at(3, 14, 0)), isFalse);
      expect(NotifQuietPrefs(on: false).covers(at(1, 23, 0)), isFalse);
      expect(NotifQuietPrefs(from: 'x').covers(at(1, 23, 0)), isFalse);
      expect(
        NotifQuietPrefs(from: '07:00', to: '07:00').covers(at(1, 7, 0)),
        isFalse,
      );
      expect(NotifQuietPrefs(from: '24:00').covers(at(1, 23, 0)), isFalse);
    });

    test('summary', () {
      final q = NotifQuietPrefs();
      q.days[5] = false;
      q.days[6] = false;
      expect(q.summary, '21:30–07:00 · weekdays');
      q.days[0] = false;
      expect(q.summary, '21:30–07:00 · 4 days');
      q.on = false;
      expect(q.summary, 'Off · updates arrive any time');
    });
  });

  test('event starts follow the Calendar scope (#485)', () {
    final p = NotifPrefs.defaults(selfId: 'me', kidIds: ['k']);
    CalendarEvent ev(List<String> who) => CalendarEvent(
      id: 'e',
      title: 'Swim',
      date: '2026-01-01',
      color: Colors.teal,
      attendees: who,
    );
    bool wants(List<String> who) =>
        p.wantsEventStart(ev(who), selfIds: {'me'}, kidIds: {'k'});

    expect(wants(['k']), isTrue);
    expect(wants(['other']), isFalse);
    p.type('cal').scope = 'me';
    expect(wants(['k']), isFalse);
    expect(wants(['me']), isTrue);
    p.type('cal')
      ..scope = 'pick'
      ..pick = ['other'];
    expect(wants(['other']), isTrue);
    p.type('cal').scope = 'all';
    expect(wants([]), isTrue);
    p.type('cal').events['start'] = false;
    expect(wants([]), isFalse);
    p.type('cal')
      ..events['start'] = true
      ..on = false;
    expect(wants([]), isFalse);
    expect(notifTypeSpec('money').channel, isNotEmpty);
  });
}
