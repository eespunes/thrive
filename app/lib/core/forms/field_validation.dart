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
    String message = 'Este campo es obligatorio.',
  }) {
    return (value) {
      if (value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  static FieldValidator email({String message = 'Introduce un email valido.'}) {
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
      if (value.length < minimumLength) {
        return message ??
            'Este campo debe tener al menos $minimumLength caracteres.';
      }
      return null;
    };
  }
}
