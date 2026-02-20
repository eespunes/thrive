import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/forms/field_validation.dart';

void main() {
  test('required validator rejects empty value', () {
    final validator = ThriveFieldValidators.required(
      message: 'Campo obligatorio.',
    );

    expect(validator('   '), 'Campo obligatorio.');
    expect(validator('ok'), isNull);
  });

  test('email validator rejects malformed email and accepts valid one', () {
    final validator = ThriveFieldValidators.email();

    expect(validator('foo@bar'), 'Introduce un email valido.');
    expect(validator('foo@bar.com'), isNull);
  });

  test('validateField returns first error in validator chain', () {
    final error = validateField('', <FieldValidator>[
      ThriveFieldValidators.required(message: 'Required'),
      ThriveFieldValidators.email(message: 'Email'),
    ]);

    expect(error, 'Required');
  });
}
