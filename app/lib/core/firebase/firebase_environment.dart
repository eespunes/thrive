import 'package:thrive_app/core/result/app_result.dart';

enum ThriveEnvironment { dev, stg, prod }

final class FirebaseProjectConfig {
  const FirebaseProjectConfig({
    required this.environment,
    required this.projectId,
    required this.appId,
    required this.storageBucket,
    required this.messagingSenderId,
    required this.serviceAccountEmail,
  });

  final ThriveEnvironment environment;
  final String projectId;
  final String appId;
  final String storageBucket;
  final String messagingSenderId;
  final String serviceAccountEmail;
}

abstract final class FirebaseEnvironmentLoader {
  static AppResult<ThriveEnvironment> load({String? rawValue}) {
    final normalizedValue =
        (rawValue ??
                const String.fromEnvironment('THRIVE_ENV', defaultValue: 'dev'))
            .trim()
            .toLowerCase();

    switch (normalizedValue) {
      case '':
      case 'dev':
      case 'development':
        return const AppSuccess<ThriveEnvironment>(ThriveEnvironment.dev);
      case 'stg':
      case 'stage':
      case 'staging':
        return const AppSuccess<ThriveEnvironment>(ThriveEnvironment.stg);
      case 'prod':
      case 'production':
        return const AppSuccess<ThriveEnvironment>(ThriveEnvironment.prod);
      default:
        return AppFailure<ThriveEnvironment>(
          FailureDetail(
            code: 'firebase_environment_invalid',
            developerMessage:
                'THRIVE_ENV has unsupported value "$normalizedValue". Expected dev/stg/prod.',
            userMessage:
                'Unable to load app configuration. Please try reinstalling the app.',
            recoverable: false,
          ),
        );
    }
  }
}

abstract final class FirebaseProjectConfigRegistry {
  static AppResult<FirebaseProjectConfig> configFor(
    ThriveEnvironment environment,
  ) {
    final config = _configsByEnvironment[environment];
    if (config != null) {
      return AppSuccess<FirebaseProjectConfig>(config);
    }

    return AppFailure<FirebaseProjectConfig>(
      FailureDetail(
        code: 'firebase_project_config_missing',
        developerMessage:
            'No Firebase project configuration found for environment "${environment.name}".',
        userMessage:
            'Unable to load app configuration. Please try reinstalling the app.',
        recoverable: false,
      ),
    );
  }

  static const Map<ThriveEnvironment, FirebaseProjectConfig>
  _configsByEnvironment = <ThriveEnvironment, FirebaseProjectConfig>{
    ThriveEnvironment.dev: FirebaseProjectConfig(
      environment: ThriveEnvironment.dev,
      projectId: 'thrive-dev',
      appId: '1:100000000001:android:thrive-dev',
      storageBucket: 'thrive-dev.appspot.com',
      messagingSenderId: '100000000001',
      serviceAccountEmail:
          'github-actions-dev@thrive-dev.iam.gserviceaccount.com',
    ),
    ThriveEnvironment.stg: FirebaseProjectConfig(
      environment: ThriveEnvironment.stg,
      projectId: 'thrive-stg',
      appId: '1:100000000002:android:thrive-stg',
      storageBucket: 'thrive-stg.appspot.com',
      messagingSenderId: '100000000002',
      serviceAccountEmail:
          'github-actions-stg@thrive-stg.iam.gserviceaccount.com',
    ),
    ThriveEnvironment.prod: FirebaseProjectConfig(
      environment: ThriveEnvironment.prod,
      projectId: 'thrive-prod',
      appId: '1:100000000003:android:thrive-prod',
      storageBucket: 'thrive-prod.appspot.com',
      messagingSenderId: '100000000003',
      serviceAccountEmail:
          'github-actions-prod@thrive-prod.iam.gserviceaccount.com',
    ),
  };
}
