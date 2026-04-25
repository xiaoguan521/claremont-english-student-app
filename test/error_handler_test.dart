import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_starter/core/error/error_handler.dart';

void main() {
  tearDown(() {
    GlobalErrorHandler.setEventRecorder(null);
  });

  test(
    'global error handler forwards error and metadata into recorder',
    () async {
      final events = <Map<String, Object?>>[];

      GlobalErrorHandler.setEventRecorder((
        eventName, {
        Map<String, Object?> payload = const <String, Object?>{},
      }) async {
        events.add(<String, Object?>{
          'eventName': eventName,
          'payload': payload,
        });
      });

      GlobalErrorHandler.reportError(
        error: StateError('practice flow failed'),
        stackTrace: StackTrace.current,
        context: 'TaskDetailPage',
        metadata: <String, dynamic>{
          'activityId': 'activity-1',
          'attemptUuid': 'attempt-1',
        },
      );

      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events.first['eventName'], 'global_error');
      expect(
        (events.first['payload'] as Map<String, Object?>)['context'],
        'TaskDetailPage',
      );
      expect(
        (events.first['payload'] as Map<String, Object?>)['errorType'],
        'StateError',
      );

      expect(events.last['eventName'], 'global_error_metadata');
      expect(
        (events.last['payload'] as Map<String, Object?>)['activityId'],
        'activity-1',
      );
      expect(
        (events.last['payload'] as Map<String, Object?>)['attemptUuid'],
        'attempt-1',
      );
    },
  );
}
