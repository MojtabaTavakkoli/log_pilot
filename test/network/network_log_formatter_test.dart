import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/src/network/network_log_formatter.dart';

void main() {
  group('NetworkLogFormatter', () {
    late NetworkLogFormatter formatter;

    setUp(() {
      setAnsiSupported(false);
      final printer = LogPilotPrinter(const LogPilotConfig(
        enabled: true,
        maskPatterns: ['Authorization', 'password'],
      ));
      formatter = NetworkLogFormatter(printer);
    });

    tearDown(() => setAnsiSupported(true));

    group('formatRequest', () {
      test('formats method and URL', () {
        final lines = formatter.formatRequest(
          method: 'GET',
          uri: Uri.parse('https://api.example.com/users'),
        );

        final joined = lines.join('\n');
        expect(joined, contains('GET'));
        expect(joined, contains('api.example.com'));
      });

      test('formats headers and masks sensitive values', () {
        final lines = formatter.formatRequest(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/login'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer secret-token',
          },
        );

        final joined = lines.join('\n');
        expect(joined, contains('Content-Type'));
        expect(joined, contains('application/json'));
        expect(joined, contains('***'));
        expect(joined, isNot(contains('secret-token')));
      });

      test('formats JSON body', () {
        final lines = formatter.formatRequest(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/data'),
          body: {'name': 'LogPilot', 'version': 1},
        );

        final joined = lines.join('\n');
        expect(joined, contains('LogPilot'));
      });
    });

    group('body masking', () {
      test('masks sensitive fields in JSON body', () {
        final printer = LogPilotPrinter(const LogPilotConfig(
          enabled: true,
          maskPatterns: ['password', 'token', 'secret'],
        ));
        final masking = NetworkLogFormatter(printer);

        final lines = masking.formatRequest(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/login'),
          body: {
            'email': 'user@test.com',
            'password': 'super-secret-123',
            'access_token': 'abc-def',
          },
        );

        final joined = lines.join('\n');
        expect(joined, contains('user@test.com'));
        expect(joined, contains('***'));
        expect(joined, isNot(contains('super-secret-123')));
        expect(joined, isNot(contains('abc-def')));
      });

      test('masks nested sensitive fields', () {
        final printer = LogPilotPrinter(const LogPilotConfig(
          enabled: true,
          maskPatterns: ['password', 'token', 'secret'],
        ));
        final masking = NetworkLogFormatter(printer);

        final lines = masking.formatResponse(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/auth'),
          statusCode: 200,
          body: {
            'user': {'name': 'Alice'},
            'credentials': {'token': 'secret-token-value'},
          },
        );

        final joined = lines.join('\n');
        expect(joined, contains('Alice'));
        expect(joined, isNot(contains('secret-token-value')));
      });
    });

    group('formatResponse', () {
      test('formats status code and duration', () {
        final lines = formatter.formatResponse(
          method: 'GET',
          uri: Uri.parse('https://api.example.com/users'),
          statusCode: 200,
          statusMessage: 'OK',
          duration: const Duration(milliseconds: 150),
        );

        final joined = lines.join('\n');
        expect(joined, contains('200'));
        expect(joined, contains('150ms'));
      });

      test('formats response body', () {
        final lines = formatter.formatResponse(
          method: 'GET',
          uri: Uri.parse('https://api.example.com/users'),
          statusCode: 200,
          body: '{"users": [{"id": 1, "name": "Alice"}]}',
        );

        final joined = lines.join('\n');
        expect(joined, contains('Alice'));
      });
    });

    group('formatError', () {
      test('formats error with status code', () {
        final lines = formatter.formatError(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/fail'),
          statusCode: 500,
          error: 'Internal Server Error',
        );

        final joined = lines.join('\n');
        expect(joined, contains('500'));
        expect(joined, contains('Internal Server Error'));
      });
    });

    group('formatGraphQL', () {
      test('formats query with variables', () {
        final lines = formatter.formatGraphQL(
          operationType: 'Query',
          operationName: 'GetUser',
          query: 'query GetUser(\$id: ID!) { user(id: \$id) { name } }',
          variables: {'id': '123'},
        );

        final joined = lines.join('\n');
        expect(joined, contains('QUERY'));
        expect(joined, contains('GetUser'));
        expect(joined, contains('123'));
      });

      test('formats GraphQL errors', () {
        final lines = formatter.formatGraphQL(
          operationType: 'Mutation',
          operationName: 'UpdateUser',
          errors: [
            {'message': 'Not authorized', 'path': ['updateUser']},
          ],
        );

        final joined = lines.join('\n');
        expect(joined, contains('Not authorized'));
        expect(joined, contains('updateUser'));
      });
    });

    group('exact-match masking (= prefix)', () {
      late NetworkLogFormatter exactFormatter;

      setUp(() {
        setAnsiSupported(false);
        final printer = LogPilotPrinter(const LogPilotConfig(
          enabled: true,
          maskPatterns: ['=accessToken', 'password'],
        ));
        exactFormatter = NetworkLogFormatter(printer);
      });

      test('exact pattern masks only the exact key', () {
        final lines = exactFormatter.formatRequest(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/auth'),
          body: {
            'accessToken': 'secret-value',
            'tokenExpiry': '2026-12-31',
            'refreshToken': 'another-secret',
          },
        );

        final joined = lines.join('\n');
        expect(joined, isNot(contains('secret-value')));
        expect(joined, contains('2026-12-31'));
        expect(joined, contains('another-secret'));
      });

      test('substring pattern still works alongside exact', () {
        final lines = exactFormatter.formatRequest(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/login'),
          body: {
            'password': 'my-pass',
            'password_hint': 'pet name',
          },
        );

        final joined = lines.join('\n');
        expect(joined, isNot(contains('my-pass')));
        expect(joined, isNot(contains('pet name')));
      });
    });

    group('regex masking (~ prefix)', () {
      late NetworkLogFormatter regexFormatter;

      setUp(() {
        setAnsiSupported(false);
        final printer = LogPilotPrinter(const LogPilotConfig(
          enabled: true,
          maskPatterns: [r'~^(access|refresh)_token$'],
        ));
        regexFormatter = NetworkLogFormatter(printer);
      });

      test('regex masks matching keys', () {
        final lines = regexFormatter.formatRequest(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/auth'),
          body: {
            'access_token': 'secret-1',
            'refresh_token': 'secret-2',
            'token_type': 'Bearer',
          },
        );

        final joined = lines.join('\n');
        expect(joined, isNot(contains('secret-1')));
        expect(joined, isNot(contains('secret-2')));
        expect(joined, contains('Bearer'));
      });
    });
  });

  group('LogPilotHttpClient.defaultLogLevelForStatus', () {
    test('returns error for 5xx', () {
      expect(LogPilotHttpClient.defaultLogLevelForStatus(500), LogLevel.error);
      expect(LogPilotHttpClient.defaultLogLevelForStatus(502), LogLevel.error);
      expect(LogPilotHttpClient.defaultLogLevelForStatus(503), LogLevel.error);
    });

    test('returns warning for 4xx', () {
      expect(LogPilotHttpClient.defaultLogLevelForStatus(400), LogLevel.warning);
      expect(LogPilotHttpClient.defaultLogLevelForStatus(401), LogLevel.warning);
      expect(LogPilotHttpClient.defaultLogLevelForStatus(404), LogLevel.warning);
      expect(LogPilotHttpClient.defaultLogLevelForStatus(422), LogLevel.warning);
      expect(LogPilotHttpClient.defaultLogLevelForStatus(429), LogLevel.warning);
    });

    test('returns info for 2xx and 3xx', () {
      expect(LogPilotHttpClient.defaultLogLevelForStatus(200), LogLevel.info);
      expect(LogPilotHttpClient.defaultLogLevelForStatus(201), LogLevel.info);
      expect(LogPilotHttpClient.defaultLogLevelForStatus(204), LogLevel.info);
      expect(LogPilotHttpClient.defaultLogLevelForStatus(301), LogLevel.info);
      expect(LogPilotHttpClient.defaultLogLevelForStatus(304), LogLevel.info);
    });
  });

  group('Mask pattern edge cases', () {
    test('empty string pattern does not mask everything', () {
      final edgePrinter = LogPilotPrinter(const LogPilotConfig(maskPatterns: ['']));
      final edgeFormatter = NetworkLogFormatter(edgePrinter);

      final lines = edgeFormatter.formatRequest(
        method: 'POST',
        uri: Uri.parse('https://api.example.com/data'),
        body: {'username': 'alice', 'token': 'secret'},
      );

      final joined = lines.join('\n');
      expect(joined, contains('alice'));
      expect(joined, contains('secret'));
    });

    test('empty exact pattern "=" does not mask everything', () {
      final edgePrinter = LogPilotPrinter(const LogPilotConfig(maskPatterns: ['=']));
      final edgeFormatter = NetworkLogFormatter(edgePrinter);

      final lines = edgeFormatter.formatRequest(
        method: 'POST',
        uri: Uri.parse('https://api.example.com/data'),
        body: {'username': 'alice'},
      );

      expect(lines.join('\n'), contains('alice'));
    });

    test('empty regex pattern "~" does not mask everything', () {
      final edgePrinter = LogPilotPrinter(const LogPilotConfig(maskPatterns: ['~']));
      final edgeFormatter = NetworkLogFormatter(edgePrinter);

      final lines = edgeFormatter.formatRequest(
        method: 'POST',
        uri: Uri.parse('https://api.example.com/data'),
        body: {'username': 'alice'},
      );

      expect(lines.join('\n'), contains('alice'));
    });

    test('invalid regex falls back to substring matching', () {
      final edgePrinter =
          LogPilotPrinter(const LogPilotConfig(maskPatterns: ['~[secret']));
      final edgeFormatter = NetworkLogFormatter(edgePrinter);

      final lines = edgeFormatter.formatRequest(
        method: 'POST',
        uri: Uri.parse('https://api.example.com/data'),
        body: {'username': 'alice', 'my_[secret_key': 'hidden'},
      );

      final joined = lines.join('\n');
      expect(joined, contains('alice'));
      expect(joined, contains('***'));
    });
  });
}
