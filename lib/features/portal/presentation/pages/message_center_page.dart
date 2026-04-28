import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_ui_tokens.dart';
import '../providers/portal_providers.dart';
import '../widgets/tablet_shell.dart';
import '../../../school/presentation/providers/school_context_provider.dart';
import '../../../student/presentation/widgets/student_dashboard_dialog_widgets.dart';
import '../../../student/presentation/widgets/student_page_gestures.dart';

class MessageCenterPage extends ConsumerWidget {
  const MessageCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portalSummaryProvider);
    final activityAsync = ref.watch(highlightedActivityProvider);
    final schoolContext = ref.watch(schoolContextProvider).valueOrNull;
    final summary = summaryAsync.valueOrNull;
    final activity = activityAsync.valueOrNull;

    return StudentPageGestures(
      onSwipeBack: () => context.go('/home'),
      child: TabletShell(
        activeSection: TabletSection.teaching,
        title: '消息中心',
        subtitle: '老师点评、学校通知和任务提醒都在这里',
        brandName: schoolContext?.displayName ?? '',
        brandLogoUrl: schoolContext?.logoUrl,
        brandSubtitle: '英语',
        theme: TabletShellTheme.k12Sky,
        child: summaryAsync.isLoading || activityAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(AppUiTokens.spaceLg - 2),
                child: StudentMessageCenterContent(
                  pendingTasks: summary?.pendingTasks ?? 0,
                  activityTitle: activity?.title,
                  className: activity?.className,
                  onOpenReviewCenter: activity == null
                      ? null
                      : () => context.go(
                          Uri(
                            path: '/reviews',
                            queryParameters: {
                              'activityTitle': activity.title,
                              'className': activity.className,
                            },
                          ).toString(),
                        ),
                ),
              ),
      ),
    );
  }
}
