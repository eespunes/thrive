typedef FieldValidator = String? Function(String value);

String? validateField(String value, List<FieldValidator> validators) {
  for (final validator in validators) {
    final validationError = validator(value);
    if (validationError != null) {
      return validationError;
    }
  }
  return null;
}

abstract final class ThriveFieldValidators {
  static FieldValidator required({
    String message = 'This field is required.',
  }) {
    return (value) {
      if (value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  static FieldValidator email({String message = 'Enter a valid email.'}) {
    const emailPattern = r'^[^@\s]+@[^@\s]+\.[^@\s]+$';
    final regularExpression = RegExp(emailPattern);

    return (value) {
      final normalizedValue = value.trim();
      if (normalizedValue.isEmpty) {
        return null;
      }
      if (!regularExpression.hasMatch(normalizedValue)) {
        return message;
      }
      return null;
    };
  }

  static FieldValidator minLength(int minimumLength, {String? message}) {
    return (value) {
      final normalizedValue = value.trim();
      if (normalizedValue.length < minimumLength) {
        return message ??
            'This field must have at least $minimumLength characters.';
      }
      return null;
    };
  }
}
