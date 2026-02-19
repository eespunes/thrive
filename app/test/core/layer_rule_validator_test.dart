import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/architecture/layer_rule_validator.dart';

void main() {
  const validator = LayerRuleValidator();

  test('accepts allowed dependency directions', () {
    final result = validator.validateImports(<String, List<String>>{
      'lib/modules/health/presentation/health_page.dart': <String>[
        'package:thrive_app/modules/health/application/health_controller.dart',
        'package:thrive_app/modules/health/domain/health_repository.dart',
        'package:thrive_app/core/result/app_result.dart',
      ],
      'lib/modules/health/application/health_controller.dart': <String>[
        'package:thrive_app/modules/health/domain/health_repository.dart',
      ],
      'lib/modules/health/data/health_repository_impl.dart': <String>[
        'package:thrive_app/modules/health/domain/health_repository.dart',
      ],
      'lib/modules/health/domain/health_repository.dart': <String>[
        'package:thrive_app/core/result/app_result.dart',
      ],
    });

    expect(result.isValid, isTrue);
    expect(result.violations, isEmpty);
  });

  test('flags disallowed dependencies with deterministic messages', () {
    final result = validator.validateImports(<String, List<String>>{
      'lib/modules/health/application/health_controller.dart': <String>[
        'package:thrive_app/modules/health/data/health_repository_impl.dart',
      ],
      'lib/modules/health/domain/health_repository.dart': <String>[
        'package:thrive_app/modules/health/presentation/health_page.dart',
      ],
    });

    expect(result.isValid, isFalse);
    expect(result.violations.length, 2);
    expect(
      result.violations.first.reason,
      'Disallowed dependency: application -> data',
    );
    expect(
      result.violations.last.reason,
      'Disallowed dependency: domain -> presentation',
    );
  });
}
