import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/log_pilot_bloc.dart';

// Test Cubit
class _CounterCubit extends Cubit<int> {
  _CounterCubit() : super(0);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
  void throwError() => addError(Exception('cubit error'), StackTrace.current);
}

// Test Bloc
abstract class _CounterEvent {}

class _Increment extends _CounterEvent {}

class _CounterBloc extends Bloc<_CounterEvent, int> {
  _CounterBloc() : super(0) {
    on<_Increment>((event, emit) => emit(state + 1));
  }
}

class _ErrorBloc extends Bloc<_CounterEvent, int> {
  _ErrorBloc() : super(0) {
    on<_Increment>((event, emit) {
      addError(Exception('bloc error'), StackTrace.current);
    });
  }
}

void main() {
  final List<LogPilotRecord> records = [];
  late LogPilotBlocObserver observer;

  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    records.clear();
    LogPilot.configure(
      config: LogPilotConfig(
        enabled: false,
        sinks: [CallbackSink(records.add)],
      ),
    );
    observer = const LogPilotBlocObserver();
    Bloc.observer = observer;
  });

  tearDown(LogPilot.reset);

  group('LogPilotBlocObserver with Cubit', () {
    test('logs cubit creation', () async {
      final cubit = _CounterCubit();
      await Future<void>.delayed(Duration.zero);

      expect(records.any((r) => r.message!.contains('Created')), isTrue);
      expect(records.any((r) => r.message!.contains('_CounterCubit')), isTrue);
      expect(records.where((r) => r.tag == 'bloc'), isNotEmpty);

      await cubit.close();
    });

    test('logs cubit close', () async {
      final cubit = _CounterCubit();
      records.clear();
      await cubit.close();

      expect(records.any((r) => r.message!.contains('Closed')), isTrue);
      expect(
          records.any((r) => r.message!.contains('_CounterCubit')), isTrue);
    });

    test('logs cubit state changes via onChange', () async {
      final cubit = _CounterCubit();
      records.clear();

      cubit.increment();
      await Future<void>.delayed(Duration.zero);

      final changeRecords =
          records.where((r) => r.message!.contains('→')).toList();
      expect(changeRecords, isNotEmpty);
      expect(changeRecords.first.tag, 'bloc');
      expect(changeRecords.first.metadata!['bloc'], '_CounterCubit');
      expect(changeRecords.first.metadata!['currentState'], '0');
      expect(changeRecords.first.metadata!['nextState'], '1');

      await cubit.close();
    });

    test('logs cubit errors', () async {
      final cubit = _CounterCubit();
      records.clear();

      cubit.throwError();
      await Future<void>.delayed(Duration.zero);

      final errorRecords =
          records.where((r) => r.error != null).toList();
      expect(errorRecords, isNotEmpty);
      expect(errorRecords.first.message, contains('cubit error'));
      expect(errorRecords.first.tag, 'bloc');

      await cubit.close();
    });
  });

  group('LogPilotBlocObserver with Bloc', () {
    test('logs bloc creation', () async {
      final bloc = _CounterBloc();
      await Future<void>.delayed(Duration.zero);

      expect(records.any((r) => r.message!.contains('Created')), isTrue);
      expect(records.any((r) => r.message!.contains('_CounterBloc')), isTrue);

      await bloc.close();
    });

    test('logs events via onEvent', () async {
      final bloc = _CounterBloc();
      records.clear();

      bloc.add(_Increment());
      await Future<void>.delayed(Duration.zero);

      final eventRecords =
          records.where((r) => r.message!.contains('←')).toList();
      expect(eventRecords, isNotEmpty);
      expect(eventRecords.first.message, contains('_Increment'));
      expect(eventRecords.first.metadata!['event'], '_Increment');

      await bloc.close();
    });

    test('logs transitions via onTransition', () async {
      final bloc = _CounterBloc();
      records.clear();

      bloc.add(_Increment());
      await Future<void>.delayed(Duration.zero);

      final transitionRecords =
          records.where((r) => r.message!.contains('→')).toList();
      expect(transitionRecords, isNotEmpty);

      await bloc.close();
    });

    test('logs bloc errors', () async {
      final bloc = _ErrorBloc();
      records.clear();

      bloc.add(_Increment());
      await Future<void>.delayed(Duration.zero);

      final errorRecords =
          records.where((r) => r.error != null).toList();
      expect(errorRecords, isNotEmpty);
      expect(errorRecords.first.message, contains('bloc error'));

      await bloc.close();
    });
  });

  group('LogPilotBlocObserver configuration', () {
    test('uses custom tag', () async {
      Bloc.observer = const LogPilotBlocObserver(tag: 'state');
      final cubit = _CounterCubit();
      await Future<void>.delayed(Duration.zero);

      expect(records.any((r) => r.tag == 'state'), isTrue);

      await cubit.close();
    });

    test('suppresses events when logEvents is false', () async {
      Bloc.observer = const LogPilotBlocObserver(logEvents: false);
      final bloc = _CounterBloc();
      records.clear();

      bloc.add(_Increment());
      await Future<void>.delayed(Duration.zero);

      final eventRecords =
          records.where((r) => r.message!.contains('←')).toList();
      expect(eventRecords, isEmpty);

      await bloc.close();
    });

    test('suppresses transitions when logTransitions is false', () async {
      Bloc.observer = const LogPilotBlocObserver(logTransitions: false);
      final cubit = _CounterCubit();
      records.clear();

      cubit.increment();
      await Future<void>.delayed(Duration.zero);

      final changeRecords =
          records.where((r) => r.message!.contains('→')).toList();
      expect(changeRecords, isEmpty);

      await cubit.close();
    });

    test('suppresses create/close when logCreations is false', () async {
      Bloc.observer = const LogPilotBlocObserver(logCreations: false);
      records.clear();

      final cubit = _CounterCubit();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      await Future<void>.delayed(Duration.zero);

      expect(records.where((r) => r.message!.contains('Created')), isEmpty);
      expect(records.where((r) => r.message!.contains('Closed')), isEmpty);
    });

    test('records include sessionId', () async {
      final cubit = _CounterCubit();
      await Future<void>.delayed(Duration.zero);

      expect(records.first.sessionId, isNotNull);

      await cubit.close();
    });

    test('records include traceId when set', () async {
      LogPilot.setTraceId('bloc-trace-42');
      final cubit = _CounterCubit();
      cubit.increment();
      await Future<void>.delayed(Duration.zero);

      final tracedRecords =
          records.where((r) => r.traceId == 'bloc-trace-42').toList();
      expect(tracedRecords, isNotEmpty);

      await cubit.close();
      LogPilot.clearTraceId();
    });
  });
}
