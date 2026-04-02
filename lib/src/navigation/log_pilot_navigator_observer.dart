import 'package:flutter/widgets.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/log_pilot.dart';

/// A [NavigatorObserver] that automatically logs route transitions.
///
/// Logs push, pop, replace, and remove events with route names,
/// arguments, and transition details. Useful for answering "what
/// screen was the user on when this error happened?"
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [LogPilotNavigatorObserver()],
/// )
/// ```
///
/// By default, logs at [LogLevel.debug] with the tag `'navigation'`.
/// Both the level and tag are configurable.
class LogPilotNavigatorObserver extends NavigatorObserver {
  /// Creates an observer that logs route transitions.
  ///
  /// [logLevel] controls the severity of navigation logs (default: debug).
  /// [tag] is the LogPilot tag used for all navigation logs (default: `'navigation'`).
  /// [logArguments] controls whether route arguments are included in metadata.
  LogPilotNavigatorObserver({
    this.logLevel = LogLevel.debug,
    this.tag = 'navigation',
    this.logArguments = true,
  });

  /// Severity level for navigation log messages.
  final LogLevel logLevel;

  /// Tag applied to all navigation log messages.
  final String tag;

  /// Whether to include route arguments in log metadata.
  ///
  /// Set to `false` if route arguments contain sensitive data.
  final bool logArguments;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(
      'PUSH',
      route: route,
      previousRoute: previousRoute,
      message: _describe('Pushed', route, from: previousRoute),
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(
      'POP',
      route: route,
      previousRoute: previousRoute,
      message: _describe('Popped', route, to: previousRoute),
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _log(
      'REPLACE',
      route: newRoute,
      previousRoute: oldRoute,
      message: _describeReplace(newRoute, oldRoute),
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _log(
      'REMOVE',
      route: route,
      previousRoute: previousRoute,
      message: _describe('Removed', route),
    );
  }

  void _log(
    String action, {
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
    required String message,
  }) {
    final metadata = <String, dynamic>{
      'action': action,
      if (route != null) 'route': _routeName(route),
      if (previousRoute != null) 'previousRoute': _routeName(previousRoute),
    };

    if (logArguments) {
      final args = route?.settings.arguments;
      if (args != null) metadata['arguments'] = args.toString();
    }

    _logAtLevel(message, metadata);
  }

  void _logAtLevel(String message, Map<String, dynamic> metadata) {
    LogPilot.log(logLevel, message, tag: tag, metadata: metadata);
  }

  String _describe(String verb, Route<dynamic> route,
      {Route<dynamic>? from, Route<dynamic>? to}) {
    final name = _routeName(route);
    final buffer = StringBuffer('$verb $name');
    if (from != null) buffer.write(' (from ${_routeName(from)})');
    if (to != null) buffer.write(' (back to ${_routeName(to)})');
    return buffer.toString();
  }

  String _describeReplace(Route<dynamic>? newRoute, Route<dynamic>? oldRoute) {
    final newName = newRoute != null ? _routeName(newRoute) : '?';
    final oldName = oldRoute != null ? _routeName(oldRoute) : '?';
    return 'Replaced $oldName with $newName';
  }

  static String _routeName(Route<dynamic> route) {
    return route.settings.name ?? route.runtimeType.toString();
  }
}
