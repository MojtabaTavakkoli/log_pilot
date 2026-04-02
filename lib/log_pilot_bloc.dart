/// BLoC observer integration for LogPilot.
///
/// ```dart
/// import 'package:log_pilot/log_pilot_bloc.dart';
///
/// void main() {
///   Bloc.observer = LogPilotBlocObserver();
///   LogPilot.init(child: const MyApp());
/// }
/// ```
library;

export 'package:log_pilot/src/state/log_pilot_bloc_observer.dart';
