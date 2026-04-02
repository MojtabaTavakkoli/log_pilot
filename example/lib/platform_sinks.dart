import 'package:log_pilot/log_pilot.dart';

/// Web fallback: no file sink available.
Future<List<LogSink>> createSinks() async => const [];

/// No file sink on web. Typed as `dynamic` because `FileSink` is
/// not available without `dart:io`. Callers guard with `kIsWeb`.
dynamic get activeFileSink => null;
