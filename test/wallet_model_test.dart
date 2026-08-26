import 'package:family_money_management_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The DiscountCard model + pure wallet helpers (epic #222): serialization
// round-trips, the local-only photo rule, masked numbers, usage logging,
// last-used labels and the symbology picker.

DiscountCard _card({String? photo}) => DiscountCard(
  id: 'c1',
  name: 'Albert Heijn',
  number: '2620541123457',
  codeType: 'barcode',
  color: const Color(0xff1684B4),
  photo: photo,
  note: 'bonus card',
  ownerId: 'me',
  timesUsed: 3,
  lastUsedMillis: 1755000000000,
  createdAtMillis: 1754000000000,
);

void main() {
  test('toJson/fromJson round-trips every field', () {
    final c = _card(photo: 'aGk=');
    final back = DiscountCard.fromJson(c.toJson());
    expect(back.toJson(), c.toJson());
    expect(back.name, 'Albert Heijn');
    expect(back.photo, 'aGk=');
    expect(back.codeType, 'barcode');
    expect(back.timesUsed, 3);
  });

  test('toJson(includePhoto: false) drops the photo — cloud payloads', () {
    final j = _card(photo: 'aGk=').toJson(includePhoto: false);
    expect(j.containsKey('photo'), isFalse);
  });

  test('fromJson defaults + sanitizes', () {
    final c = DiscountCard.fromJson({'name': 'Shop', 'number': '12-34 56x'});
    expect(c.id, isNotEmpty);
    expect(c.number, '123456'); // digits-only
    expect(c.codeType, 'barcode');
    expect(c.timesUsed, 0);
    expect(c.lastUsedMillis, isNull);
    expect(DiscountCard.fromJson({'codeType': 'qr'}).codeType, 'qr');
  });

  test('maskedNumber shows the last four digits', () {
    expect(_card().maskedNumber, '•••• 3457');
    expect(DiscountCard.fromJson({'number': '12'}).maskedNumber, '•••• 12');
    expect(DiscountCard.fromJson({}).maskedNumber, '');
  });

  test('logUse bumps the counter and last-used stamp', () {
    final c = _card();
    c.logUse(1756000000000);
    expect(c.timesUsed, 4);
    expect(c.lastUsedMillis, 1756000000000);
  });

  test('digitsOnly strips everything but digits', () {
    expect(digitsOnly(' 12-34 ab 56 '), '123456');
    expect(digitsOnly(''), '');
  });

  test('mergeCardPhotos restores local-only photos by id', () {
    final incoming = [
      DiscountCard.fromJson({'id': 'a', 'name': 'A'}),
      DiscountCard.fromJson({'id': 'b', 'name': 'B'}),
    ];
    final local = [_card(photo: 'aGk=')..id = 'a'];
    mergeCardPhotos(incoming, local);
    expect(incoming[0].photo, 'aGk=');
    expect(incoming[1].photo, isNull);
  });

  test('cardLastUsedLabel gives the design copy', () {
    final now = DateTime(2026, 8, 25, 14);
    expect(cardLastUsedLabel(null, now), 'not used yet');
    expect(
      cardLastUsedLabel(DateTime(2026, 6, 26).millisecondsSinceEpoch, now),
      'last used 26 Jun',
    );
  });

  test('cardSpacedNumber groups digits in fours', () {
    expect(cardSpacedNumber('5901234123457'), '5901 2341 2345 7');
    expect(cardSpacedNumber('12345678'), '1234 5678');
    expect(cardSpacedNumber(''), '');
  });

  test('isValidEan13 checks length, digits and the check digit', () {
    expect(isValidEan13('5901234123457'), isTrue);
    expect(isValidEan13('5901234123456'), isFalse); // bad check digit
    expect(isValidEan13('12345'), isFalse);
    expect(isValidEan13('590123412345a'), isFalse);
  });

  test('cardBarcodeFor picks QR / EAN-13 / Code 128', () {
    final qr = _card()..codeType = 'qr';
    final ean = _card()..number = '5901234123457';
    final other = _card()..number = '12345678';
    expect(cardBarcodeFor(qr).name, 'QR-Code');
    expect(cardBarcodeFor(ean).name, 'EAN 13');
    expect(cardBarcodeFor(other).name, 'CODE 128');
  });

  test('ExpenseItem round-trips cardId and copyWithId keeps it', () {
    final it = ExpenseItem.fromJson({
      'id': 'e1',
      'label': 'Groceries',
      'marker': '12',
      'amount': 40,
      'paid': false,
      'account': 'shared',
      'cardId': 'c1',
    });
    expect(it.cardId, 'c1');
    expect(ExpenseItem.fromJson(it.toJson()).cardId, 'c1');
    expect(it.copyWithId('e2').cardId, 'c1');
    final none = ExpenseItem.fromJson({
      'id': 'e3',
      'label': 'x',
      'marker': '',
      'amount': 1,
      'paid': false,
      'account': 'shared',
      'cardId': '  ',
    });
    expect(none.cardId, isNull);
    expect(none.toJson().containsKey('cardId'), isFalse);
  });

  test('analytics ring buffer records and caps events', () {
    kAnalyticsEvents.clear();
    logAnalyticsEvent('card_scanned', {'codeType': 'qr'});
    expect(kAnalyticsEvents.single.name, 'card_scanned');
    expect(kAnalyticsEvents.single.props['codeType'], 'qr');
    for (var i = 0; i < 220; i++) {
      logAnalyticsEvent('e$i');
    }
    expect(kAnalyticsEvents.length, 200);
    kAnalyticsEvents.clear();
  });
}
