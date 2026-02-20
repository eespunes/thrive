import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/forms/field_validation.dart';

void main() {
  test('required validator rejects empty value', () {
    final validator = ThriveFieldValidators.required(
      message: 'This field is required.',
    );

    expect(validator('   '), 'This field is required.');
    expect(validator('ok'), isNull);
  });

  test('email validator rejects malformed email and accepts valid one', () {
    final validator = ThriveFieldValidators.email();

    expect(validator('foo@bar'), 'Enter a valid email.');
    expect(validator('foo@bar.com'), isNull);
  });

  test(
    'minLength validator rejects short strings and accepts sufficiently long strings',
    () {
      final validator = ThriveFieldValidators.minLength(
        3,
        message: 'Must have at least 3 characters.',
      );

      expect(validator('ab'), 'Must have at least 3 characters.');
      expect(validator('abc'), isNull);
      expect(validator('  ab  '), 'Must have at least 3 characters.');
      expect(validator('abcd'), isNull);
    },
  );

  test('validateField returns first error in validator chain', () {
    final error = validateField('', <FieldValidator>[
      ThriveFieldValidators.required(message: 'Required'),
      ThriveFieldValidators.email(message: 'Email'),
    ]);

    expect(error, 'Required');
  });
}
