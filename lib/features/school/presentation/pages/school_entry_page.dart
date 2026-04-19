import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/school_context_provider.dart';

class SchoolEntryPage extends ConsumerStatefulWidget {
  const SchoolEntryPage({required this.schoolCode, super.key});

  final String schoolCode;

  @override
  ConsumerState<SchoolEntryPage> createState() => _SchoolEntryPageState();
}

class _SchoolEntryPageState extends ConsumerState<SchoolEntryPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(preferredSchoolSlugProvider.notifier)
          .setSlug(widget.schoolCode);
      if (!mounted) return;
      final isAuthenticated = ref.read(authProvider).isAuthenticated;
      context.go(isAuthenticated ? '/home' : '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
