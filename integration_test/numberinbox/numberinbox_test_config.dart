import 'package:patrol_finders/patrol_finders.dart' show PatrolTesterConfig;

/// Patrol's defaults wait 10 seconds for a widget to appear or the frames to
/// settle. These tests drive a real backend on a shared CI runner, where a
/// response can take longer; a slow answer must not fail a step that is only
/// waiting for it. Failures that are real still end the test at this limit.
const slowStackConfig = PatrolTesterConfig(
  printLogs: true,
  existsTimeout: Duration(seconds: 60),
  visibleTimeout: Duration(seconds: 60),
  settleTimeout: Duration(seconds: 60),
);
