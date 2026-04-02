import 'package:bloc/bloc.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/log_pilot.dart';

/// A [BlocObserver] that logs BLoC and Cubit lifecycle events through LogPilot.
///
/// Logs create, close, event, change (transition), and error events so
/// that state management activity appears in the same timeline as regular
/// application logs, file sinks, and history.
///
/// ```dart
/// void main() {
///   Bloc.observer = LogPilotBlocObserver();
///   LogPilot.init(child: const MyApp());
/// }
/// ```
///
/// By default, lifecycle events (create/close) are logged at [LogLevel.debug],
/// state changes at [LogLevel.info], events at [LogLevel.debug], and
/// errors at [LogLevel.error]. All levels are configurable.
class LogPilotBlocObserver extends BlocObserver {
  /// Creates an observer that logs BLoC/Cubit events through LogPilot.
  ///
  /// [tag] is the LogPilot tag used for all BLoC logs (default: `'bloc'`).
  /// [logEvents] controls whether incoming events are logged.
  /// [logTransitions] controls whether state changes are logged.
  /// [logCreations] controls whether create/close lifecycle events are logged.
  const LogPilotBlocObserver({
    this.tag = 'bloc',
    this.logEvents = true,
    this.logTransitions = true,
    this.logCreations = true,
    this.eventLevel = LogLevel.debug,
    this.transitionLevel = LogLevel.info,
    this.creationLevel = LogLevel.debug,
    this.errorLevel = LogLevel.error,
  });

  /// Tag applied to all BLoC log messages.
  final String tag;

  /// Whether to log incoming events (added to a Bloc).
  final bool logEvents;

  /// Whether to log state transitions (Change / Transition).
  final bool logTransitions;

  /// Whether to log create/close lifecycle events.
  final bool logCreations;

  /// Log level for event messages.
  final LogLevel eventLevel;

  /// Log level for state transition messages.
  final LogLevel transitionLevel;

  /// Log level for create/close messages.
  final LogLevel creationLevel;

  /// Log level for error messages.
  final LogLevel errorLevel;

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    if (!logCreations) return;
    _logAt(
      creationLevel,
      'Created ${_blocName(bloc)}',
      metadata: {'bloc': _blocName(bloc)},
    );
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    if (!logCreations) return;
    _logAt(
      creationLevel,
      'Closed ${_blocName(bloc)}',
      metadata: {'bloc': _blocName(bloc)},
    );
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (!logEvents) return;
    _logAt(
      eventLevel,
      '${_blocName(bloc)} ← ${event.runtimeType}',
      metadata: {
        'bloc': _blocName(bloc),
        'event': event.runtimeType.toString(),
        'eventData': event.toString(),
      },
    );
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    if (!logTransitions) return;
    // For Bloc subclasses, onTransition fires as well and includes the
    // event that triggered the change — skip onChange to avoid double
    // logging. Cubits only fire onChange, so we log here for them.
    if (bloc is Bloc) return;
    _logAt(
      transitionLevel,
      '${_blocName(bloc)}: ${change.currentState.runtimeType} → '
          '${change.nextState.runtimeType}',
      metadata: {
        'bloc': _blocName(bloc),
        'currentState': change.currentState.toString(),
        'nextState': change.nextState.toString(),
      },
    );
  }

  @override
  void onTransition(
      Bloc<dynamic, dynamic> bloc, Transition<dynamic, dynamic> transition) {
    super.onTransition(bloc, transition);
    if (!logTransitions) return;
    _logAt(
      transitionLevel,
      '${_blocName(bloc)}: ${transition.event.runtimeType} → '
          '${transition.nextState.runtimeType}',
      metadata: {
        'bloc': _blocName(bloc),
        'event': transition.event.runtimeType.toString(),
        'currentState': transition.currentState.toString(),
        'nextState': transition.nextState.toString(),
      },
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    _logAt(
      errorLevel,
      '${_blocName(bloc)}: $error',
      metadata: {'bloc': _blocName(bloc)},
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _logAt(
    LogLevel level,
    String message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    LogPilot.log(level, message,
        tag: tag, metadata: metadata, error: error, stackTrace: stackTrace);
  }

  String _blocName(BlocBase<dynamic> bloc) => bloc.runtimeType.toString();
}
