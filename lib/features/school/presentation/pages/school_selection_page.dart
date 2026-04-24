import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/school_context_provider.dart';

class SchoolSelectionPage extends ConsumerWidget {
  const SchoolSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = ref.watch(availableSchoolContextsProvider);
    final currentUserEmail = ref.watch(currentUserEmailProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2F67F6), Color(0xFF69C8FF), Color(0xFFF6F7FB)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Card(
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: optionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const _StateMessage(
                    title: '学校列表加载失败',
                    message: '请稍后重试，或联系老师确认账号权限。',
                  ),
                  data: (options) {
                    if (options.isEmpty) {
                      return const _StateMessage(
                        title: '当前账号还没有绑定学校',
                        message: '请联系老师或管理员为你开通学校权限。',
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择今天要进入的学校',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          currentUserEmail == null
                              ? '这个账号已绑定多个学校，请先选择一个学校再继续学习。'
                              : '$currentUserEmail 已绑定多个学校，请先选择今天要进入的学校。',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 24),
                        ...options.map(
                          (option) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _SchoolChoiceCard(option: option),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SchoolChoiceCard extends ConsumerWidget {
  const _SchoolChoiceCard({required this.option});

  final SchoolContext option;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolLabel = option.schoolName.isNotEmpty
        ? option.schoolName
        : '学校入口';
    final schoolSubtitle = option.schoolName.isNotEmpty
        ? option.welcomeMessage
        : '入口编码：${option.slug}';

    return InkWell(
      onTap: () async {
        await ref
            .read(preferredSchoolSlugProvider.notifier)
            .setSlug(option.slug);
        if (!context.mounted) return;
        context.go('/home');
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: option.primaryColor.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: option.primaryColor.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [option.primaryColor, option.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schoolLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    schoolSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            FilledButton.icon(
              onPressed: () async {
                await ref
                    .read(preferredSchoolSlugProvider.notifier)
                    .setSlug(option.slug);
                if (!context.mounted) return;
                context.go('/home');
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('进入'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
