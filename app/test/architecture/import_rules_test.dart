import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrive_app/core/architecture/layer_rule_validator.dart';

void main() {
  test('project files respect layer import rules', () async {
    const validator = LayerRuleValidator();
    final importsByFile = await _collectProjectImports();

    final result = validator.validateImports(importsByFile);

    expect(result.isValid, isTrue, reason: _formatViolations(result));
  });
}

Future<Map<String, List<String>>> _collectProjectImports() async {
  final files =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final importPattern = RegExp("^\\s*import\\s+'([^']+)';", multiLine: true);
  final importsByFile = <String, List<String>>{};

  for (final file in files) {
    final source = await file.readAsString();
    final imports =
        importPattern
            .allMatches(source)
            .map((match) => match.group(1))
            .whereType<String>()
            .where((path) => path.startsWith('package:thrive_app/'))
            .toList()
          ..sort();

    importsByFile[file.path.replaceAll('\\\\', '/')] = imports;
  }

  return importsByFile;
}

String _formatViolations(LayerValidationResult result) {
  if (result.violations.isEmpty) {
    return 'No violations';
  }

  return result.violations
      .map(
        (violation) =>
            '${violation.reason} at ${violation.sourceFile} -> ${violation.targetImport}',
      )
      .join('\n');
}
