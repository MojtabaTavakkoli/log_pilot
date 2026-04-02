/// LogPilot — prettified, structured console logging for Flutter.
///
/// ```dart
/// import 'package:log_pilot/log_pilot.dart';
///
/// void main() {
///   LogPilot.init(config: LogPilotConfig(), child: const MyApp());
/// }
///
/// // Anywhere:
/// LogPilot.info('Hello world');
/// ```
library;

// Facade (the main user-facing class)
export 'package:log_pilot/src/log_pilot.dart';

// Scoped instance logger
export 'package:log_pilot/src/log_pilot_logger.dart';

// Core
export 'package:log_pilot/src/core/breadcrumb.dart';
export 'package:log_pilot/src/core/ansi_styles.dart'
    show AnsiColor, AnsiStyle, setAnsiSupported, isAnsiSupported, stripAnsi;
export 'package:log_pilot/src/core/export_format.dart';
export 'package:log_pilot/src/core/log_history.dart';
export 'package:log_pilot/src/core/log_level.dart';
export 'package:log_pilot/src/core/log_sink.dart';
export 'package:log_pilot/src/core/output_format.dart';
export 'package:log_pilot/src/core/log_pilot_config.dart';
export 'package:log_pilot/src/core/log_pilot_diagnostics.dart';
export 'package:log_pilot/src/core/log_pilot_printer.dart';
export 'package:log_pilot/src/core/log_pilot_record.dart';

// Navigation
export 'package:log_pilot/src/navigation/log_pilot_navigator_observer.dart';

// UI — Debug overlay
export 'package:log_pilot/src/ui/log_pilot_overlay.dart';

// Error handling
export 'package:log_pilot/src/errors/log_pilot_zone.dart'
    show LogPilotZone, LogPilotErrorCallback;
export 'package:log_pilot/src/errors/stack_trace_simplifier.dart';

// Network — http package (lightweight, always available)
export 'package:log_pilot/src/network/log_pilot_http_interceptor.dart';
