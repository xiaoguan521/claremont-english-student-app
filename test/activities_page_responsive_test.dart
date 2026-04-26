import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/core/providers/theme_provider.dart';
import 'package:flutter_starter/features/portal/data/portal_models.dart';
import 'package:flutter_starter/features/portal/presentation/pages/activities_page.dart';
import 'package:flutter_starter/features/portal/presentation/providers/portal_providers.dart';
import 'package:flutter_starter/features/school/presentation/providers/school_context_provider.dart';

void main() {
  Future<void> pumpActivitiesPage(
    WidgetTester tester, {
    Size viewport = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime(2026, 4, 26);
    final activities = <PortalActivity>[
      PortalActivity(
        id: 'activity-today',
        title: 'Unit 3 Reading Mission',
        className: '三年级 1 班',
        dateLabel: '今天',
        dueDate: today,
        status: ActivityStatus.active,
        reviewCount: 2,
        inspectCount: 0,
        urgeCount: 0,
        completionRate: 0.5,
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
            title: 'Word bank mission',
            kind: TaskKind.phonics,
            reviewStatus: TaskReviewStatus.pendingReview,
            previewAsset: 'preview2.png',
            promptText: 'Tap the words in order.',
            ttsText: 'Nice to meet you.',
          ),
        ],
        submissionFlowStatus: SubmissionFlowStatus.notStarted,
      ),
      PortalActivity(
        id: 'activity-yesterday',
        title: 'Unit 2 Review',
        className: '三年级 1 班',
        dateLabel: '昨天',
        dueDate: today.subtract(const Duration(days: 1)),
        status: ActivityStatus.completed,
        reviewCount: 1,
        inspectCount: 0,
        urgeCount: 0,
        completionRate: 1,
        tasks: const [
          PortalTask(
            id: 'task-3',
            title: 'Review recording',
            kind: TaskKind.recording,
            reviewStatus: TaskReviewStatus.checked,
            previewAsset: 'preview3.png',
            promptText: 'Review the dialogue.',
            ttsText: 'How old are you?',
          ),
        ],
        submissionFlowStatus: SubmissionFlowStatus.completed,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          portalActivitiesProvider.overrideWith((ref) async => activities),
          todayActivityDateProvider.overrideWith((ref) => today),
          schoolContextProvider.overrideWith(
            (ref) async => SchoolContext.fallback('demo'),
          ),
        ],
        child: const MaterialApp(home: ActivitiesPage()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('activities page stays stable on portrait mobile', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    await pumpActivitiesPage(tester, viewport: const Size(390, 844));

    expect(find.text('我的作业'), findsOneWidget);
    expect(find.text('回首页'), findsOneWidget);
    expect(find.text('刷新'), findsOneWidget);
    expect(find.text('今日作业'), findsOneWidget);
    expect(find.text('待完成'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('Unit 3 Reading Mission'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'activities page stays stable across responsive landscape viewports',
    (WidgetTester tester) async {
      addTearDown(tester.view.reset);

      const viewports = <Size>[
        Size(932, 430),
        Size(1080, 640),
        Size(1200, 700),
        Size(1400, 900),
      ];

      for (final viewport in viewports) {
        await pumpActivitiesPage(tester, viewport: viewport);

        expect(find.text('回首页'), findsOneWidget);
        expect(find.text('刷新'), findsOneWidget);
        expect(find.text('今日作业'), findsOneWidget);
        expect(find.text('待完成'), findsOneWidget);
        expect(find.text('已完成'), findsOneWidget);
        expect(find.text('Unit 3 Reading Mission'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
