import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/school_context_provider.dart';

class SchoolLinkListener extends ConsumerStatefulWidget {
  const SchoolLinkListener({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<SchoolLinkListener> createState() => _SchoolLinkListenerState();
}

class _SchoolLinkListenerState extends ConsumerState<SchoolLinkListener> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _lastHandledSlug;

  @override
  void initState() {
    super.initState();
    _bindInitialLink();
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleUri);
  }

  Future<void> _bindInitialLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (_) {
      // Keep the app usable even when initial universal link lookup fails.
    }
  }

  Future<void> _handleUri(Uri uri) async {
    final slug = _extractSchoolSlug(uri);
    if (!mounted || slug == null || slug.isEmpty || slug == _lastHandledSlug) {
      return;
    }

    _lastHandledSlug = slug;
    await ref.read(preferredSchoolSlugProvider.notifier).setSlug(slug);

    if (!mounted) return;
    final target = '/s/$slug';
    if (widget.router.state.matchedLocation != target) {
      widget.router.go(target);
    }
  }

  String? _extractSchoolSlug(Uri uri) {
    final schoolQuery =
        uri.queryParameters['school'] ?? uri.queryParameters['schoolCode'];
    if (schoolQuery != null && schoolQuery.trim().isNotEmpty) {
      return schoolQuery.trim();
    }

    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    if (segments.length >= 2 &&
        (segments.first == 's' || segments.first == 'school')) {
      return segments[1];
    }

    return null;
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
