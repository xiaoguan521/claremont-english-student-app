import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/core/providers/theme_provider.dart';
import 'package:flutter_starter/features/portal/data/portal_models.dart';
import 'package:flutter_starter/features/portal/presentation/pages/task_detail_page.dart';
import 'package:flutter_starter/features/portal/presentation/providers/parent_contact_providers.dart';
import 'package:flutter_starter/features/portal/presentation/providers/portal_providers.dart';
import 'package:flutter_starter/features/portal/presentation/providers/student_feature_flags_provider.dart';
import 'package:flutter_starter/features/portal/presentation/widgets/audio_record_button.dart';
import 'package:flutter_starter/features/school/presentation/providers/school_context_provider.dart';

void main() {
  Future<void> pumpTaskDetailPage(
    WidgetTester tester, {
    Size viewport = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final activity = PortalActivity(
      id: 'activity-1',
      title: 'Unit 3 Reading Mission',
      className: '三年级 1 班',
      dateLabel: '今天',
      dueDate: DateTime(2026, 4, 26),
      status: ActivityStatus.active,
      reviewCount: 0,
      inspectCount: 0,
      urgeCount: 0,
      completionRate: 0.4,
      tasks: const [
        PortalTask(
          id: 'task-1',
          title: 'Read after the teacher',
          kind: TaskKind.recording,
          reviewStatus: TaskReviewStatus.inProgress,
          previewAsset: 'preview.png',
          promptText: 'Listen and repeat.',
          ttsText: 'Hello, how are you?',
        ),
        PortalTask(
          id: 'task-2',
          title: 'Say the chant',
          kind: TaskKind.dubbing,
          reviewStatus: TaskReviewStatus.pendingReview,
          previewAsset: 'preview2.png',
          promptText: 'Read the chant aloud.',
          ttsText: 'Nice to meet you.',
        ),
      ],
      submissionFlowStatus: SubmissionFlowStatus.notStarted,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          portalActivityByIdProvider.overrideWith((ref, activityId) async {
            return activity;
          }),
          parentContactSummaryProvider.overrideWith(
            (ref, activityId) async => null,
          ),
          schoolContextProvider.overrideWith(
            (ref) async => SchoolContext.fallback('demo'),
          ),
          studentFeatureFlagsProvider.overrideWith(
            (ref) => const StudentFeatureFlags(),
          ),
        ],
        child: const MaterialApp(
          home: TaskDetailPage(activityId: 'activity-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('task detail page stays stable on portrait mobile', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    await pumpTaskDetailPage(tester, viewport: const Size(430, 932));

    expect(find.text('返回作业'), findsOneWidget);
    expect(find.text('Read after the teacher'), findsOneWidget);
    expect(find.byType(AudioRecordButton), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'task detail page stays stable across responsive landscape viewports',
    (WidgetTester tester) async {
      addTearDown(tester.view.reset);

      const viewports = <Size>[
        Size(932, 430),
        Size(1080, 640),
        Size(1200, 700),
        Size(1400, 900),
      ];

      for (final viewport in viewports) {
        await pumpTaskDetailPage(tester, viewport: viewport);

        expect(find.text('Read after the teacher'), findsWidgets);
        expect(find.byType(AudioRecordButton), findsWidgets);
        // final exception = tester.takeException();
        // expect(exception, isNull, reason: 'viewport: $viewport\n$exception');
      }
    },
  );
}
