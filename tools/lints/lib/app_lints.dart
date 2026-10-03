import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/no_io_in_voice_feature.dart';
import 'src/no_service_locator_outside_root.dart';
import 'src/no_string_literals_in_widgets.dart';
import 'src/no_wall_clock.dart';

PluginBase createPlugin() => _AppLints();

class _AppLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        NoWallClock(),
        NoServiceLocatorOutsideRoot(),
        NoStringLiteralsInWidgets(),
        NoIoInVoiceFeature(),
      ];
}
