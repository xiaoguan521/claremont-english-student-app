import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/core/providers/theme_provider.dart';
import 'package:flutter_starter/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_starter/features/home/presentation/pages/home_page.dart';
import 'package:flutter_starter/features/portal/data/portal_models.dart';
import 'package:flutter_starter/features/portal/presentation/pages/explore_page.dart';
import 'package:flutter_starter/features/portal/presentation/providers/parent_contact_providers.dart';
import 'package:flutter_starter/features/portal/presentation/providers/portal_providers.dart';
import 'package:flutter_starter/features/portal/presentation/providers/student_feature_flags_provider.dart';
import 'package:flutter_starter/features/school/presentation/providers/school_context_provider.dart';

void main() {
  Future<void> pumpStudentHome(
    WidgetTester tester, {
    StudentFeatureFlags featureFlags = const StudentFeatureFlags(),
    Size viewport = const Size(1400, 900),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fakeActivity = PortalActivity(
      id: 'activity-1',
      title: 'Unit 3 Reading Mission',
      className: '三年级 1 班',
      dateLabel: '今天',
      dueDate: DateTime(2026, 4, 25),
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
      ],
      submissionFlowStatus: SubmissionFlowStatus.notStarted,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          highlightedActivityProvider.overrideWith((ref) async => fakeActivity),
          portalSummaryProvider.overrideWith(
            (ref) async => const PortalSummary(
              activeClasses: 1,
              totalActivities: 3,
              completedActivities: 1,
              inProgressActivities: 2,
              pendingTasks: 4,
            ),
          ),
          dailyGrowthSummaryProvider.overrideWith(
            (ref) async => const DailyGrowthSummary(
              totalStars: 12,
              bestCombo: 2,
              completedTasks: 1,
              breakReminderCount: 0,
              backgroundSwitchCount: 0,
            ),
          ),
          schoolContextProvider.overrideWith(
            (ref) async => SchoolContext.fallback('demo'),
          ),
          currentUserEmailProvider.overrideWith((ref) => 'kid@example.com'),
          parentContactSummaryProvider.overrideWith(
            (ref, activityId) async => null,
          ),
          studentFeatureFlagsProvider.overrideWith((ref) => featureFlags),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('tablet home page renders student learning sections', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    await pumpStudentHome(tester);

    expect(find.text('今日英语'), findsOneWidget);
    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('老师点评'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-900, 0));
    await tester.pumpAndSettle();
    expect(find.text('今日任务'), findsWidgets);
    expect(find.text('点评中心'), findsOneWidget);

    await tester.tap(find.text('老师点评'));
    await tester.pumpAndSettle();
    expect(find.text('先完成今天的作业'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.text('英语学习'));
    await tester.pumpAndSettle();
    expect(find.text('我的学校'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape phone home page keeps unified dashboard layout', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    await pumpStudentHome(tester, viewport: const Size(932, 430));

    expect(find.text('英语学习'), findsOneWidget);
    expect(find.text('老师点评'), findsOneWidget);
    expect(find.text('今日主线'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(find.text('今日课表'), findsOneWidget);
    expect(find.text('任务中心'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact tablet home page second screen still renders cards', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    await pumpStudentHome(tester, viewport: const Size(1080, 640));

    await tester.drag(find.byType(PageView), const Offset(-820, 0));
    await tester.pumpAndSettle();

    expect(find.text('今日任务'), findsWidgets);
    expect(find.text('点评中心'), findsOneWidget);
    expect(find.text('任务中心'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home page stays stable across responsive landscape viewports', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);

    const viewports = <Size>[
      Size(932, 430),
      Size(1080, 640),
      Size(1200, 700),
      Size(1400, 900),
    ];

    for (final viewport in viewports) {
      await pumpStudentHome(tester, viewport: viewport);

      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('老师点评'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(PageView), const Offset(-760, 0));
      await tester.pumpAndSettle();

      expect(find.text('今日任务'), findsWidgets);
      expect(find.text('任务中心'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('home page hides growth rewards when reward flag is off', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.reset);
    await pumpStudentHome(
      tester,
      featureFlags: const StudentFeatureFlags(
        showGrowthRewards: false,
        showEnhancedHealthInsights: true,
        showFunZonePromos: true,
      ),
    );

    expect(find.textContaining('星币'), findsNothing);
    expect(find.text('任务'), findsOneWidget);
  });

  testWidgets(
    'explore page shows fallback state when fun zone promos are off',
    (WidgetTester tester) async {
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentFeatureFlagsProvider.overrideWith(
              (ref) => const StudentFeatureFlags(
                showGrowthRewards: true,
                showEnhancedHealthInsights: true,
                showFunZonePromos: false,
              ),
            ),
          ],
          child: const MaterialApp(home: ExplorePage()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('拓展乐园稍后开放'), findsOneWidget);
      expect(find.text('先去完成主线作业'), findsOneWidget);
    },
  );
}
