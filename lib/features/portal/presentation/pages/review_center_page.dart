import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_ui_tokens.dart';
import '../../data/portal_models.dart';
import '../providers/portal_providers.dart';
import '../providers/student_feature_flags_provider.dart';
import '../widgets/tablet_shell.dart';
import '../../../school/presentation/providers/school_context_provider.dart';
import '../../../student/presentation/widgets/student_dashboard_dialog_widgets.dart';
import '../../../student/presentation/widgets/student_page_gestures.dart';

class ReviewCenterPage extends ConsumerWidget {
  const ReviewCenterPage({super.key, this.activityTitle, this.className});

  final String? activityTitle;
  final String? className;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(highlightedActivityProvider);
    final schoolContext = ref.watch(schoolContextProvider).valueOrNull;
    final featureFlags = ref.watch(studentFeatureFlagsProvider);

    return StudentPageGestures(
      onSwipeBack: () => context.go('/home'),
      child: TabletShell(
        activeSection: TabletSection.teaching,
        title: '点评中心',
        subtitle: '听老师反馈，找到下一次更棒的读法',
        brandName: schoolContext?.displayName ?? '',
        brandLogoUrl: schoolContext?.logoUrl,
        brandSubtitle: '英语',
        theme: TabletShellTheme.k12Sky,
        child: !featureFlags.reviewCenterV2
            ? const _ReviewCenterStateMessage(
                title: '点评中心稳定模式已开启',
                message: '新点评流已临时收起，作业和录音数据仍会正常保存。',
              )
            : activityAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _ReviewCenterStateMessage(
                  title: '点评暂时没有同步成功',
                  message: '请检查网络，或稍后再来看看老师的新反馈。',
                ),
                data: (activity) {
                  final rows = _reviewRows(
                    context,
                    activity: activity,
                    activityTitle: activityTitle,
                    className: className,
                  );
                  if (rows.isEmpty) {
                    return const _ReviewCenterStateMessage(
                      title: '还没有点评',
                      message: '完成作业后，老师点评和 AI 诊断会出现在这里。',
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(18),
                    child: StudentReviewFeed(items: rows),
                  );
                },
              ),
      ),
    );
  }

  List<StudentReviewFeedItem> _reviewRows(
    BuildContext context, {
    required PortalActivity? activity,
    String? activityTitle,
    String? className,
  }) {
    final title = activityTitle ?? activity?.title ?? '5天打卡活动';
    final klass = className ?? activity?.className ?? '精品英语 H 班';
    final tasks = activity?.tasks ?? const <PortalTask>[];
    final reviewedTasks = tasks
        .where(
          (task) =>
              task.hasReview ||
              task.reviewStatus == TaskReviewStatus.checked ||
              task.reviewStatus == TaskReviewStatus.pendingReview,
        )
        .toList();
    final sourceTasks = reviewedTasks.isNotEmpty
        ? reviewedTasks
        : tasks.take(4).toList();

    if (sourceTasks.isNotEmpty) {
      return [
        for (final entry in sourceTasks.asMap().entries)
          StudentReviewFeedItem(
            title: entry.value.title,
            tag: entry.value.kind == TaskKind.recording ? '录音' : '练习',
            belongTo: '$klass · $title',
            teacher: '张嘉琪',
            dateLabel: entry.key == 0 ? '今天' : '04/${21 - entry.key}',
            highlighted:
                entry.value.reviewStatus == TaskReviewStatus.pendingReview,
            onTap: () => _openReview(
              context,
              id: entry.value.id,
              title: entry.value.title,
              belongTo: '$klass · $title',
              teacher: '张嘉琪',
            ),
          ),
      ];
    }

    final fallback = [
      ('sing-the-song', 'Sing the song', '$klass · $title', '04/21\n23:12'),
      ('montys-phonics', 'Monty\'s phonics', '$klass · $title', '04/19\n23:13'),
      ('say-the-chant', 'Say the chant', '$klass · 3天打卡活动', '04/14\n22:19'),
      (
        'listen-and-correct',
        'Listen and correct',
        '$klass · 3天打卡活动',
        '04/14\n22:19',
      ),
    ];

    return [
      for (final entry in fallback.asMap().entries)
        StudentReviewFeedItem(
          title: entry.value.$2,
          tag: '录音',
          belongTo: entry.value.$3,
          teacher: '张嘉琪',
          dateLabel: entry.value.$4,
          highlighted: entry.key == 2,
          onTap: () => _openReview(
            context,
            id: entry.value.$1,
            title: entry.value.$2,
            belongTo: entry.value.$3,
            teacher: '张嘉琪',
          ),
        ),
    ];
  }

  void _openReview(
    BuildContext context, {
    required String id,
    required String title,
    required String belongTo,
    required String teacher,
  }) {
    context.go(
      Uri(
        path: '/reviews/$id',
        queryParameters: {
          'title': title,
          'belongTo': belongTo,
          'teacher': teacher,
        },
      ).toString(),
    );
  }
}

class _ReviewCenterStateMessage extends StatelessWidget {
  const _ReviewCenterStateMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppUiTokens.studentPanel,
          borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.rate_review_rounded,
              color: AppUiTokens.studentAccentBlue,
              size: 52,
            ),
            const SizedBox(height: AppUiTokens.spaceSm + 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppUiTokens.studentInk,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppUiTokens.spaceXs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppUiTokens.studentMuted,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
