enum ArchitectureLayer {
  presentation,
  application,
  domain,
  data,
  core,
  unknown,
}

class LayerViolation {
  const LayerViolation({
    required this.sourceFile,
    required this.sourceLayer,
    required this.targetImport,
    required this.targetLayer,
    required this.reason,
  });

  final String sourceFile;
  final ArchitectureLayer sourceLayer;
  final String targetImport;
  final ArchitectureLayer targetLayer;
  final String reason;
}

class LayerValidationResult {
  const LayerValidationResult(this.violations);

  final List<LayerViolation> violations;

  bool get isValid => violations.isEmpty;
}

class LayerRuleValidator {
  const LayerRuleValidator();

  LayerValidationResult validateImports(
    Map<String, List<String>> importsByFile,
  ) {
    final files = importsByFile.keys.toList()..sort();
    final violations = <LayerViolation>[];

    for (final file in files) {
      final sourceLayer = _detectLayer(file);
      final imports = List<String>.of(importsByFile[file] ?? <String>[])
        ..sort();

      for (final target in imports) {
        final targetLayer = _detectLayer(target);

        if (!_isImportAllowed(
          sourceLayer: sourceLayer,
          targetLayer: targetLayer,
        )) {
          violations.add(
            LayerViolation(
              sourceFile: file,
              sourceLayer: sourceLayer,
              targetImport: target,
              targetLayer: targetLayer,
              reason: _reasonFor(sourceLayer, targetLayer),
            ),
          );
        }
      }
    }

    return LayerValidationResult(List<LayerViolation>.unmodifiable(violations));
  }

  ArchitectureLayer _detectLayer(String rawPath) {
    var normalized = rawPath.replaceAll('\\', '/');
    normalized = normalized.replaceAll('package:thrive_app/', '/');

    if (normalized.contains('/presentation/')) {
      return ArchitectureLayer.presentation;
    }
    if (normalized.contains('/application/')) {
      return ArchitectureLayer.application;
    }
    if (normalized.contains('/domain/')) {
      return ArchitectureLayer.domain;
    }
    if (normalized.contains('/data/')) {
      return ArchitectureLayer.data;
    }
    if (normalized.contains('/core/')) {
      return ArchitectureLayer.core;
    }

    return ArchitectureLayer.unknown;
  }

  bool _isImportAllowed({
    required ArchitectureLayer sourceLayer,
    required ArchitectureLayer targetLayer,
  }) {
    if (sourceLayer == ArchitectureLayer.unknown ||
        targetLayer == ArchitectureLayer.unknown ||
        targetLayer == ArchitectureLayer.core) {
      return true;
    }

    switch (sourceLayer) {
      case ArchitectureLayer.presentation:
        return targetLayer == ArchitectureLayer.application ||
            targetLayer == ArchitectureLayer.domain;
      case ArchitectureLayer.application:
        return targetLayer == ArchitectureLayer.domain;
      case ArchitectureLayer.data:
        return targetLayer == ArchitectureLayer.domain;
      case ArchitectureLayer.domain:
      case ArchitectureLayer.core:
        return false;
      case ArchitectureLayer.unknown:
        return true;
    }
  }

  String _reasonFor(ArchitectureLayer source, ArchitectureLayer target) {
    return 'Disallowed dependency: ${source.name} -> ${target.name}';
  }
}
