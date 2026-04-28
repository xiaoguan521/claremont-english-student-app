import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_breakpoints.dart';
import '../providers/student_identity_provider.dart';

class StudentIdentitySelectionPage extends ConsumerWidget {
  const StudentIdentitySelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(availableStudentProfilesProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF87DFFF), Color(0xFF78E55A), Color(0xFFFFF0A8)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              final contentMaxWidth = responsiveWidthCap(
                viewport.maxWidth,
                fraction: 0.9,
                min: 320,
                max: 920,
              );
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: profilesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const _IdentityStateMessage(
                      title: '学生身份加载失败',
                      message: '请稍后重试，或联系老师确认账号绑定关系。',
                    ),
                    data: (profiles) {
                      if (profiles.isEmpty) {
                        return const _IdentityStateMessage(
                          title: '还没有绑定学生',
                          message: '请联系老师或管理员完成学生账号绑定。',
                        );
                      }

                      return Card(
                        elevation: 14,
                        color: Colors.white.withValues(alpha: 0.94),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(34),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(
                            viewport.maxWidth < 720 ? 18 : 30,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '今天谁来学习？',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: const Color(0xFF17335F),
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '点击自己的大头像，进入专属英语主页。',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 18,
                                runSpacing: 18,
                                alignment: WrapAlignment.center,
                                children: profiles
                                    .map(
                                      (profile) => _StudentAvatarChoice(
                                        profile: profile,
                                        onTap: () async {
                                          await ref
                                              .read(
                                                selectedStudentProfileProvider
                                                    .notifier,
                                              )
                                              .select(profile.id);
                                          if (!context.mounted) return;
                                          context.go('/home');
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StudentAvatarChoice extends StatelessWidget {
  const _StudentAvatarChoice({required this.profile, required this.onTap});

  final StudentIdentityProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFEAF7FF)],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7BEF).withValues(alpha: 0.14),
                blurRadius: 22,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: const Color(0xFFDDF4FF),
                backgroundImage: profile.avatarUrl.isEmpty
                    ? null
                    : NetworkImage(profile.avatarUrl),
                child: profile.avatarUrl.isEmpty
                    ? const Icon(
                        Icons.child_care_rounded,
                        size: 52,
                        color: Color(0xFF2E7BEF),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                profile.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF17335F),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityStateMessage extends StatelessWidget {
  const _IdentityStateMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF17335F),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
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
      ),
    );
  }
}
