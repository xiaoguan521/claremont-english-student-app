import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/portal_repository.dart';
import '../../data/queued_submission_storage.dart';
import '../providers/parent_contact_providers.dart';
import '../providers/portal_providers.dart';
import '../providers/sync_queue_providers.dart';

class AppSyncQueueListener extends ConsumerStatefulWidget {
  const AppSyncQueueListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppSyncQueueListener> createState() =>
      _AppSyncQueueListenerState();
}

class _AppSyncQueueListenerState extends ConsumerState<AppSyncQueueListener>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _networkRecoveredTimer;
  bool _isOffline = false;
  bool _showRecoveredBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (!mounted) {
        return;
      }
      _handleConnectivityResults(results);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _processPendingQueue();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _networkRecoveredTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshStudentData();
      _processPendingQueue();
    }
  }

  Future<void> _processPendingQueue() {
    return ref
        .read(syncQueueStatusProvider.notifier)
        .processPendingUploads(
          portalRepository: ref.read(portalRepositoryProvider),
          submissionStorage: ref.read(queuedSubmissionStorageProvider),
          onActivitySynced: (activityId) {
            _refreshStudentData(activityId: activityId);
          },
        );
  }

  void _refreshStudentData({String? activityId}) {
    ref.invalidate(portalActivitiesProvider);
    ref.invalidate(activityCalendarDatesProvider);
    ref.invalidate(visibleActivityDateProvider);
    ref.invalidate(activitiesForSelectedDateProvider);
    ref.invalidate(highlightedActivityProvider);
    ref.invalidate(portalSummaryProvider);
    ref.invalidate(selectedDatePortalSummaryProvider);
    ref.invalidate(syncQueueStatusProvider);
    ref.invalidate(dailyGrowthSummaryProvider);

    if (activityId != null && activityId.isNotEmpty) {
      ref.invalidate(portalActivityByIdProvider(activityId));
      ref.invalidate(parentContactSummaryProvider(activityId));
    }
  }

  Future<void> _bootstrapConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) {
      return;
    }
    _handleConnectivityResults(results, triggerSync: false);
  }

  void _handleConnectivityResults(
    List<ConnectivityResult> results, {
    bool triggerSync = true,
  }) {
    final hadOfflineState = _isOffline;
    final hasNetwork = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isOffline = !hasNetwork;
      if (_isOffline) {
        _showRecoveredBanner = false;
      }
    });

    if (hasNetwork) {
      if (hadOfflineState) {
        _networkRecoveredTimer?.cancel();
        setState(() {
          _showRecoveredBanner = true;
        });
        _networkRecoveredTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) {
            return;
          }
          setState(() {
            _showRecoveredBanner = false;
          });
        });
      }
      if (triggerSync) {
        _refreshStudentData();
        _processPendingQueue();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueStatus = ref.watch(syncQueueStatusProvider);
    final pendingCount = queueStatus.maybeWhen(
      data: (value) => value.pendingCount,
      orElse: () => 0,
    );
    final showSyncingBanner =
        !_isOffline && !_showRecoveredBanner && pendingCount > 0;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              ignoring: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: _isOffline
                    ? const _NetworkStatusBanner(
                        key: ValueKey('offline'),
                        icon: Icons.cloud_off_rounded,
                        message: '当前网络不稳定，先进入离线学习模式。',
                        backgroundColor: Color(0xFFFEF3C7),
                        foregroundColor: Color(0xFF92400E),
                      )
                    : _showRecoveredBanner
                    ? const _NetworkStatusBanner(
                        key: ValueKey('recovered'),
                        icon: Icons.cloud_done_rounded,
                        message: '网络已经恢复，正在帮你同步学习记录。',
                        backgroundColor: Color(0xFFE0F2FE),
                        foregroundColor: Color(0xFF0C4A6E),
                      )
                    : showSyncingBanner
                    ? _NetworkStatusBanner(
                        key: const ValueKey('syncing'),
                        icon: Icons.sync_rounded,
                        message: '正在同步 $pendingCount 条学习记录。',
                        backgroundColor: const Color(0xFFEAFBF1),
                        foregroundColor: const Color(0xFF166534),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NetworkStatusBanner extends StatelessWidget {
  const _NetworkStatusBanner({
    required this.icon,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    super.key,
  });

  final IconData icon;
  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: foregroundColor.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: foregroundColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
