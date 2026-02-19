sealed class AppResult<T> {
  const AppResult();

  R when<R>({
    required R Function(T value) success,
    required R Function(FailureDetail failure) failure,
  }) {
    final current = this;
    if (current is AppSuccess<T>) {
      return success(current.value);
    }

    return failure((current as AppFailure<T>).detail);
  }

  bool get isSuccess => this is AppSuccess<T>;
  bool get isFailure => this is AppFailure<T>;
}

final class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);

  final T value;
}

final class AppFailure<T> extends AppResult<T> {
  const AppFailure(this.detail);

  final FailureDetail detail;
}

class FailureDetail {
  const FailureDetail({
    required this.code,
    required this.developerMessage,
    required this.userMessage,
    required this.recoverable,
  });

  final String code;
  final String developerMessage;
  final String userMessage;
  final bool recoverable;
}
