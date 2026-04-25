import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../school/presentation/providers/school_context_provider.dart';
import '../../data/app_event_log_repository.dart';
import '../providers/student_feature_flags_provider.dart';
import '../widgets/tablet_shell.dart';

class StudentReleaseLabPage extends ConsumerWidget {
  const StudentReleaseLabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(studentFeatureFlagsProvider);
    final logEntriesAsync = ref.watch(appEventLogEntriesProvider);
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    return TabletShell(
      activeSection: TabletSection.teaching,
      brandName: schoolContext.displayName,
      brandLogoUrl: schoolContext.logoUrl,
      brandSubtitle: '学校学习入口',
      title: '学生端发布实验室',
      subtitle: '用于联调、灰度和本地诊断，不面向学生日常使用',
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SectionCard(
            title: '灰度开关',
            subtitle: '这里的修改会持久化到本机，重启应用后仍然生效。',
            child: Column(
              children: [
                _FlagTile(
                  title: '成长奖励展示',
                  subtitle: '控制首页和作业完成态里的星币、连对等强化包装。',
                  value: flags.showGrowthRewards,
                  onChanged: (value) => _updateFlags(
                    ref,
                    flags.copyWith(showGrowthRewards: value),
                  ),
                ),
                _FlagTile(
                  title: '健康摘要增强',
                  subtitle: '控制联系家长页里的强化健康可信感区块。',
                  value: flags.showEnhancedHealthInsights,
                  onChanged: (value) => _updateFlags(
                    ref,
                    flags.copyWith(showEnhancedHealthInsights: value),
                  ),
                ),
                _FlagTile(
                  title: '趣味区包装',
                  subtitle: '控制首页趣味入口和更多页的推广包装。',
                  value: flags.showFunZonePromos,
                  onChanged: (value) => _updateFlags(
                    ref,
                    flags.copyWith(showFunZonePromos: value),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(studentFeatureFlagsControllerProvider.notifier)
                        .resetToDefaults(
                          ref.read(studentFeatureFlagDefaultsProvider),
                        ),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('恢复默认配置'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '最近事件日志',
            subtitle: '用于排查同步、恢复、提交和异常收口是否按预期工作。',
            action: TextButton.icon(
              onPressed: () async {
                await ref.read(appEventLogRepositoryProvider).clear();
                ref.invalidate(appEventLogEntriesProvider);
              },
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('清空日志'),
            ),
            child: logEntriesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Text('日志暂时读取失败。'),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Text('当前还没有记录到本地事件日志。');
                }
                final visibleEntries = entries.reversed.toList();
                return Column(
                  children: [
                    for (final entry in visibleEntries)
                      _LogEntryTile(entry: entry),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFlags(WidgetRef ref, StudentFeatureFlags next) {
    return ref
        .read(studentFeatureFlagsControllerProvider.notifier)
        .update(next);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FlagTile extends StatelessWidget {
  const _FlagTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF475569),
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final AppEventLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final payloadText = entry.payload.entries
        .map((item) => '${item.key}: ${item.value}')
        .join('  |  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.eventName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatTimestamp(entry.timestamp),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (payloadText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              payloadText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
