import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';
import 'package:thrive_app/core/design_system/thrive_theme.dart';
import 'package:thrive_app/core/observability/app_logger.dart';

void main() {
  test('builds theme from tokens and logs load event', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;

    final logger = InMemoryAppLogger();

    final theme = ThriveTheme.build(logger: logger);

    expect(theme.scaffoldBackgroundColor, ThriveColors.cloud);
    expect(theme.colorScheme.primary, ThriveColors.forest);
    expect(theme.textTheme.headlineSmall?.fontSize, 28);
    expect(
      theme.textTheme.headlineSmall?.fontFamily,
      startsWith(ThriveTypography.titleFontFamily),
    );
    expect(
      theme.textTheme.bodyMedium?.fontFamily,
      ThriveTypography.bodyFontFamily,
    );
    expect(logger.events.any((event) => event.code == 'theme_loaded'), isTrue);
  });
}
