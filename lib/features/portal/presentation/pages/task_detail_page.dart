import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../school/presentation/providers/school_context_provider.dart';
import '../../data/portal_models.dart';
import '../../data/portal_repository.dart';
import '../providers/portal_providers.dart';
import '../widgets/tablet_shell.dart';
import 'reading_page.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  const TaskDetailPage({required this.activityId, super.key});

  final String activityId;

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _recorder = AudioRecorder();

  bool _isSubmitting = false;
  bool _isRecording = false;
  String? _recordingPath;
  String? _speakingTaskId;
  _PendingAudioFile? _selectedAudio;

  @override
  void initState() {
    super.initState();
    _configureTts();
  }

  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _speakingTaskId = null;
      });
    });
    _tts.setCancelHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _speakingTaskId = null;
      });
    });
    _tts.setErrorHandler((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _speakingTaskId = null;
      });
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    if (_isRecording) {
      _showMessage('请先结束当前录音，再选择已有音频。');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'mp4', 'wav', 'aac'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    if (file.bytes == null) {
      _showMessage('这次没有拿到音频内容，请重新选择。');
      return;
    }

    setState(() {
      _selectedAudio = _PendingAudioFile(
        name: file.name,
        bytes: file.bytes!,
        sizeBytes: file.size,
        mimeType: _guessMimeType(file.extension),
      );
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showMessage('需要先允许麦克风权限，才能开始录音。');
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/student-reading-${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _recordingPath = path;
      });
      _showMessage('已经开始录音了，读完后点“结束录音并保存”。');
    } catch (_) {
      _showMessage('录音启动失败，请稍后重试。');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final stoppedPath = await _recorder.stop();
      final resolvedPath = stoppedPath ?? _recordingPath;

      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingPath = null;
        });
      }

      if (resolvedPath == null) {
        _showMessage('这次录音没有保存成功，请再试一次。');
        return;
      }

      final file = File(resolvedPath);
      if (!await file.exists()) {
        _showMessage('没有找到刚才录下来的音频文件。');
        return;
      }

      final bytes = await file.readAsBytes();
      final sizeBytes = await file.length();
      final fileName = resolvedPath.split(Platform.pathSeparator).last;

      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAudio = _PendingAudioFile(
          name: fileName,
          bytes: bytes,
          sizeBytes: sizeBytes,
          mimeType: 'audio/mp4',
        );
      });
      _showMessage('录音已经保存好了，可以直接提交给老师。');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        _recordingPath = null;
      });
      _showMessage('结束录音时出了点问题，请重新试一次。');
    }
  }

  Future<void> _speakSample(PortalTask task) async {
    final text = _sampleTextFor(task);
    if (text == null) {
      _showMessage('这项任务还没有配置示范朗读内容。');
      return;
    }

    if (_speakingTaskId == task.id) {
      await _tts.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _speakingTaskId = null;
      });
      return;
    }

    await _tts.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _speakingTaskId = task.id;
    });

    final result = await _tts.speak(text);
    if (!mounted) {
      return;
    }
    if (result != 1) {
      setState(() {
        _speakingTaskId = null;
      });
      _showMessage('示范朗读暂时没有播放成功，请稍后重试。');
    }
  }

  Future<void> _openReadingPage(
    PortalActivity activity, {
    PortalTask? task,
  }) async {
    if ((activity.materialPdfPath ?? '').trim().isEmpty) {
      _showMessage('老师还没有上传教材 PDF。');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReadingPage(activity: activity, task: task),
      ),
    );
  }

  Future<void> _handlePrimaryAction(PortalActivity activity) async {
    if (_isRecording) {
      _showMessage('请先结束录音并保存，再提交给老师。');
      return;
    }

    if (activity.submissionFlowStatus == SubmissionFlowStatus.queued ||
        activity.submissionFlowStatus == SubmissionFlowStatus.processing) {
      _showMessage('老师已经收到你的练习，正在处理中。');
      return;
    }

    if (activity.submissionFlowStatus == SubmissionFlowStatus.completed) {
      _showMessage('老师点评就在下方，往下滑就能查看完整反馈。');
      return;
    }

    final selectedAudio = _selectedAudio;
    if (selectedAudio == null) {
      _showMessage('先录一段音频或选择已有音频，再提交给老师。');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(portalRepositoryProvider)
          .uploadAudioSubmission(
            activityId: widget.activityId,
            fileBytes: selectedAudio.bytes,
            fileName: selectedAudio.name,
            sizeBytes: selectedAudio.sizeBytes,
            mimeType: selectedAudio.mimeType,
          );
      ref.invalidate(portalActivitiesProvider);
      ref.invalidate(portalSummaryProvider);
      ref.invalidate(portalActivityByIdProvider(widget.activityId));
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAudio = null;
      });
      _showMessage('已经提交给老师了，记得晚点回来查看点评。');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('提交失败，请稍后再试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final activityAsync = ref.watch(
      portalActivityByIdProvider(widget.activityId),
    );
    final schoolContext =
        ref.watch(schoolContextProvider).valueOrNull ??
        SchoolContext.fallback();

    if (activityAsync.isLoading) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        brandName: schoolContext.displayName,
        brandSubtitle: '学校学习入口',
        title: '任务详情',
        subtitle: '正在加载今天的学习任务',
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (activityAsync.hasError) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        brandName: schoolContext.displayName,
        brandSubtitle: '学校学习入口',
        title: '任务详情',
        subtitle: '加载失败',
        child: Center(
          child: Text(
            '任务加载失败，请稍后重试。',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    final activity = activityAsync.valueOrNull;
    if (activity == null) {
      return TabletShell(
        activeSection: TabletSection.teaching,
        brandName: schoolContext.displayName,
        brandSubtitle: '学校学习入口',
        title: '任务详情',
        subtitle: '内容不存在',
        child: Center(
          child: Text(
            '没有找到这份作业。',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    final completedTasks = activity.tasks
        .where((task) => task.reviewStatus == TaskReviewStatus.checked)
        .length;

    return TabletShell(
      activeSection: TabletSection.teaching,
      brandName: schoolContext.displayName,
      brandSubtitle: '学校学习入口',
      title: activity.title,
      subtitle: '${activity.className} · ${activity.dateLabel}',
      actions: [
        _HeaderAction(
          icon: Icons.arrow_back_rounded,
          label: '返回作业',
          onTap: () => context.go('/activities'),
        ),
      ],
      child: Column(
        children: [
          _OverviewCard(
            activity: activity,
            completedTasks: completedTasks,
            isSubmitting: _isSubmitting,
            onPrimaryAction: () => _handlePrimaryAction(activity),
            onOpenMaterial: () => _openReadingPage(activity),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: activity.tasks.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SubmissionPanel(
                    activity: activity,
                    isSubmitting: _isSubmitting,
                    isRecording: _isRecording,
                    selectedAudio: _selectedAudio,
                    onPickAudio: _pickAudioFile,
                    onRecordAudio: _toggleRecording,
                    onPrimaryAction: () => _handlePrimaryAction(activity),
                  );
                }

                final task = activity.tasks[index - 1];
                return _TaskCard(
                  index: index,
                  task: task,
                  isSpeaking: _speakingTaskId == task.id,
                  onAction: () => _handleTaskAction(activity, task),
                  onOpenReading: activity.materialPdfPath == null
                      ? null
                      : () => _openReadingPage(activity, task: task),
                  onSpeakSample: _sampleTextFor(task) == null
                      ? null
                      : () => _speakSample(task),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleTaskAction(PortalActivity activity, PortalTask task) {
    switch (task.reviewStatus) {
      case TaskReviewStatus.checked:
        _showMessage('老师点评已经生成了，往上滑一点就能看到。');
        return;
      case TaskReviewStatus.pendingReview:
        _showMessage('这项练习已经提交，老师正在查看。');
        return;
      case TaskReviewStatus.inProgress:
        _handlePrimaryAction(activity);
        return;
    }
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.activity,
    required this.completedTasks,
    required this.isSubmitting,
    required this.onPrimaryAction,
    required this.onOpenMaterial,
  });

  final PortalActivity activity;
  final int completedTasks;
  final bool isSubmitting;
  final VoidCallback onPrimaryAction;
  final VoidCallback onOpenMaterial;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = _primaryActionLabel(activity.submissionFlowStatus);
    final buttonEnabled = _canSubmit(activity.submissionFlowStatus);
    final submittedLabel = activity.submittedAt == null
        ? '还没有提交'
        : '提交于 ${_formatDateTime(activity.submittedAt!)}';
    final scoreLabel = activity.latestScore == null
        ? '等待老师评分'
        : '老师评分 ${activity.latestScore!.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF34D399), Color(0xFF2F67F6)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 56,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.className,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '今天先按顺序完成下面 ${activity.tasks.length} 个学习任务。',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if ((activity.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    activity.description!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _OverviewChip(
                      icon: Icons.check_circle_rounded,
                      label: '已完成 $completedTasks 项',
                    ),
                    _OverviewChip(
                      icon: Icons.schedule_rounded,
                      label: submittedLabel,
                    ),
                    _OverviewChip(
                      icon: Icons.mark_chat_read_rounded,
                      label: scoreLabel,
                    ),
                    if ((activity.materialTitle ?? '').trim().isNotEmpty)
                      _OverviewChip(
                        icon: Icons.picture_as_pdf_rounded,
                        label: activity.materialTitle!,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenMaterial,
                icon: const Icon(Icons.menu_book_rounded),
                label: const Text('打开教材'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: buttonEnabled && !isSubmitting
                    ? onPrimaryAction
                    : null,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_primaryActionIcon(activity.submissionFlowStatus)),
                label: Text(isSubmitting ? '提交中' : buttonLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmissionPanel extends StatelessWidget {
  const _SubmissionPanel({
    required this.activity,
    required this.isSubmitting,
    required this.isRecording,
    required this.selectedAudio,
    required this.onPickAudio,
    required this.onRecordAudio,
    required this.onPrimaryAction,
  });

  final PortalActivity activity;
  final bool isSubmitting;
  final bool isRecording;
  final _PendingAudioFile? selectedAudio;
  final VoidCallback onPickAudio;
  final VoidCallback onRecordAudio;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    switch (activity.submissionFlowStatus) {
      case SubmissionFlowStatus.notStarted:
        return _MessagePanel(
          title: isRecording ? '正在录音中' : '完成朗读后记得提交',
          subtitle: isRecording
              ? '读完后点击“结束录音并保存”，然后再把音频提交给老师。'
              : '可以先打开教材、听示范，再用原生录音完成本次练习。',
          badgeLabel: isRecording ? '录音进行中' : '还没有提交',
          badgeColor: isRecording
              ? const Color(0xFFDC2626)
              : const Color(0xFF2563EB),
          selectedAudioLabel: selectedAudio?.name,
          existingAudioLabel: activity.submissionAudioName,
          onPickAudio: isRecording ? null : onPickAudio,
          onRecordAudio: onRecordAudio,
          recordActionLabel: isRecording ? '结束录音并保存' : '开始录音',
          actionLabel: isSubmitting ? '提交中' : '提交本次练习',
          actionIcon: isSubmitting
              ? null
              : const Icon(Icons.cloud_upload_rounded),
          onAction: isSubmitting || isRecording ? null : onPrimaryAction,
        );
      case SubmissionFlowStatus.queued:
        return _MessagePanel(
          title: '老师已经收到这次练习',
          subtitle: activity.submittedAt == null
              ? '现在进入等待点评状态，老师会尽快给你反馈。'
              : '你已在 ${_formatDateTime(activity.submittedAt!)} 提交，老师会尽快给你反馈。',
          badgeLabel: '等待老师点评',
          badgeColor: const Color(0xFFF97316),
          existingAudioLabel: activity.submissionAudioName,
        );
      case SubmissionFlowStatus.processing:
        return _MessagePanel(
          title: '系统正在整理评分结果',
          subtitle: '这份练习已经进入处理流程，稍后就能看到分数和鼓励语。',
          badgeLabel: '评分处理中',
          badgeColor: const Color(0xFF7C3AED),
          existingAudioLabel: activity.submissionAudioName,
        );
      case SubmissionFlowStatus.failed:
        return _MessagePanel(
          title: isRecording ? '正在重新录音' : '这次提交没有成功',
          subtitle: isRecording
              ? '读完后点击“结束录音并保存”，再重新提交给老师。'
              : '你可以重新录一段音频，或者换一个文件再提交。',
          badgeLabel: isRecording ? '录音进行中' : '需要重新提交',
          badgeColor: isRecording
              ? const Color(0xFFDC2626)
              : const Color(0xFFDC2626),
          selectedAudioLabel: selectedAudio?.name,
          existingAudioLabel: activity.submissionAudioName,
          onPickAudio: isRecording ? null : onPickAudio,
          onRecordAudio: onRecordAudio,
          recordActionLabel: isRecording ? '结束录音并保存' : '重新录音',
          actionLabel: isSubmitting ? '重新提交中' : '重新提交',
          actionIcon: isSubmitting ? null : const Icon(Icons.refresh_rounded),
          onAction: isSubmitting || isRecording ? null : onPrimaryAction,
        );
      case SubmissionFlowStatus.completed:
        return _FeedbackPanel(activity: activity);
    }
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    this.selectedAudioLabel,
    this.existingAudioLabel,
    this.onPickAudio,
    this.onRecordAudio,
    this.recordActionLabel,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final String? selectedAudioLabel;
  final String? existingAudioLabel;
  final VoidCallback? onPickAudio;
  final VoidCallback? onRecordAudio;
  final String? recordActionLabel;
  final String? actionLabel;
  final Widget? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    badgeLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (selectedAudioLabel != null ||
                    existingAudioLabel != null) ...[
                  const SizedBox(height: 14),
                  _AudioInfoCard(
                    title: selectedAudioLabel != null ? '准备提交的音频' : '已上传的音频',
                    fileName: selectedAudioLabel ?? existingAudioLabel!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (onRecordAudio != null)
                FilledButton.tonalIcon(
                  onPressed: onRecordAudio,
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(recordActionLabel ?? '开始录音'),
                ),
              if (onPickAudio != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onPickAudio,
                  icon: const Icon(Icons.library_music_rounded),
                  label: Text(selectedAudioLabel == null ? '选择音频' : '重新选择'),
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: actionIcon ?? const SizedBox.shrink(),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AudioInfoCard extends StatelessWidget {
  const _AudioInfoCard({required this.title, required this.fileName});

  final String title;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audio_file_rounded, color: Color(0xFF2F67F6)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                fileName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.activity});

  final PortalActivity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '老师点评已完成',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF16A34A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (activity.latestScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '老师评分 ${activity.latestScore!.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF2F67F6),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            activity.latestFeedback ?? '老师已经完成点评，你这次的练习表现不错。',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (activity.encouragement != null) ...[
            const SizedBox(height: 12),
            Text(
              activity.encouragement!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (activity.strengths.isNotEmpty ||
              activity.improvementPoints.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _FeedbackListCard(
                    title: '这次做得好的地方',
                    items: activity.strengths.isEmpty
                        ? const ['老师觉得你的整体状态不错。']
                        : activity.strengths,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _FeedbackListCard(
                    title: '下次可以继续加强',
                    items: activity.improvementPoints.isEmpty
                        ? const ['继续保持稳定的语速和句尾停顿。']
                        : activity.improvementPoints,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackListCard extends StatelessWidget {
  const _FeedbackListCard({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2F67F6)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.index,
    required this.task,
    required this.isSpeaking,
    required this.onAction,
    this.onOpenReading,
    this.onSpeakSample,
  });

  final int index;
  final PortalTask task;
  final bool isSpeaking;
  final VoidCallback onAction;
  final VoidCallback? onOpenReading;
  final VoidCallback? onSpeakSample;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(task.reviewStatus);
    final statusColor = _statusColor(task.reviewStatus);
    final actionLabel = _actionLabel(task.reviewStatus);
    final sampleText = _sampleTextFor(task);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF2F67F6),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Container(
                width: 92,
                height: 74,
                decoration: BoxDecoration(
                  gradient: _previewGradient(task.kind),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _previewIcon(task.kind),
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '学习方式：${task.previewAsset}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((task.promptText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        task.promptText!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (sampleText != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          sampleText,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            statusLabel,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        if (task.hasPageRange)
                          _TaskInfoChip(
                            icon: Icons.menu_book_rounded,
                            label: _pageRangeLabel(task),
                          ),
                        if (sampleText != null)
                          _TaskInfoChip(
                            icon: isSpeaking
                                ? Icons.pause_circle_filled_rounded
                                : Icons.volume_up_rounded,
                            label: isSpeaking ? '示范朗读播放中' : '可播放示范朗读',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (onOpenReading != null)
                OutlinedButton.icon(
                  onPressed: onOpenReading,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('打开教材'),
                ),
              if (onSpeakSample != null) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onSpeakSample,
                  icon: Icon(
                    isSpeaking
                        ? Icons.stop_circle_rounded
                        : Icons.record_voice_over_rounded,
                  ),
                  label: Text(isSpeaking ? '停止示范' : '听示范'),
                ),
              ],
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: Icon(_actionIcon(task.reviewStatus)),
                label: Text(actionLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return '这项任务已经有点评';
      case TaskReviewStatus.pendingReview:
        return '已经提交，老师正在查看';
      case TaskReviewStatus.inProgress:
        return '完成后记得提交给老师';
    }
  }

  Color _statusColor(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return const Color(0xFF16A34A);
      case TaskReviewStatus.pendingReview:
        return const Color(0xFFF97316);
      case TaskReviewStatus.inProgress:
        return const Color(0xFF2563EB);
    }
  }

  String _actionLabel(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return '查看点评';
      case TaskReviewStatus.pendingReview:
        return '等待点评';
      case TaskReviewStatus.inProgress:
        return '提交练习';
    }
  }

  IconData _actionIcon(TaskReviewStatus status) {
    switch (status) {
      case TaskReviewStatus.checked:
        return Icons.rate_review_outlined;
      case TaskReviewStatus.pendingReview:
        return Icons.schedule_rounded;
      case TaskReviewStatus.inProgress:
        return Icons.cloud_upload_rounded;
    }
  }

  LinearGradient _previewGradient(TaskKind kind) {
    switch (kind) {
      case TaskKind.dubbing:
        return const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF2563EB)],
        );
      case TaskKind.recording:
        return const LinearGradient(
          colors: [Color(0xFFEC4899), Color(0xFFF97316)],
        );
      case TaskKind.phonics:
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
        );
    }
  }

  IconData _previewIcon(TaskKind kind) {
    switch (kind) {
      case TaskKind.dubbing:
        return Icons.mic_external_on_rounded;
      case TaskKind.recording:
        return Icons.graphic_eq_rounded;
      case TaskKind.phonics:
        return Icons.spellcheck_rounded;
    }
  }
}

class _TaskInfoChip extends StatelessWidget {
  const _TaskInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2F67F6)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _canSubmit(SubmissionFlowStatus status) {
  switch (status) {
    case SubmissionFlowStatus.notStarted:
    case SubmissionFlowStatus.failed:
      return true;
    case SubmissionFlowStatus.queued:
    case SubmissionFlowStatus.processing:
    case SubmissionFlowStatus.completed:
      return false;
  }
}

String _primaryActionLabel(SubmissionFlowStatus status) {
  switch (status) {
    case SubmissionFlowStatus.notStarted:
      return '提交本次练习';
    case SubmissionFlowStatus.failed:
      return '重新提交';
    case SubmissionFlowStatus.queued:
      return '等待老师点评';
    case SubmissionFlowStatus.processing:
      return '评分处理中';
    case SubmissionFlowStatus.completed:
      return '查看点评';
  }
}

IconData _primaryActionIcon(SubmissionFlowStatus status) {
  switch (status) {
    case SubmissionFlowStatus.notStarted:
      return Icons.cloud_upload_rounded;
    case SubmissionFlowStatus.failed:
      return Icons.refresh_rounded;
    case SubmissionFlowStatus.queued:
      return Icons.schedule_rounded;
    case SubmissionFlowStatus.processing:
      return Icons.auto_awesome_rounded;
    case SubmissionFlowStatus.completed:
      return Icons.rate_review_outlined;
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}.${local.day} ${local.hour}:$minute';
}

String _guessMimeType(String? extension) {
  switch ((extension ?? '').toLowerCase()) {
    case 'wav':
      return 'audio/wav';
    case 'aac':
      return 'audio/aac';
    case 'm4a':
    case 'mp4':
      return 'audio/mp4';
    case 'mp3':
    default:
      return 'audio/mpeg';
  }
}

String? _sampleTextFor(PortalTask task) {
  final candidates = [task.ttsText, task.expectedText, task.promptText];
  for (final candidate in candidates) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String _pageRangeLabel(PortalTask task) {
  final start = task.startPage;
  final end = task.endPage;
  if (start != null && end != null && start != end) {
    return '第 $start - $end 页';
  }
  final target = start ?? end;
  return target == null ? '教材页码' : '第 $target 页';
}

class _PendingAudioFile {
  const _PendingAudioFile({
    required this.name,
    required this.bytes,
    required this.sizeBytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final int sizeBytes;
  final String mimeType;
}
