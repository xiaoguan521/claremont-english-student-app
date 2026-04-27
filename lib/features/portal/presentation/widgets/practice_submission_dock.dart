import 'package:flutter/material.dart';

import '../../data/portal_models.dart';
import 'audio_record_button.dart';
import 'practice_control_dock.dart';

class PracticeSubmissionDock extends StatelessWidget {
  const PracticeSubmissionDock({
    super.key,
    required this.submissionFlowStatus,
    required this.submissionStatusHint,
    required this.isUnsupportedProtocol,
    required this.requiresPracticeCompletion,
    required this.isPracticeCompleted,
    required this.selectedAudioLabel,
    required this.existingAudioLabel,
    required this.isSubmitting,
    required this.isRecording,
    required this.isSelectedAudioPlaying,
    required this.isSelectedAudioLoading,
    required this.isStoredAudioPlaying,
    required this.isStoredAudioLoading,
    this.onRecordAudio,
    this.onClearSelectedAudio,
    this.onPlaySelectedAudio,
    this.onPlayStoredAudio,
    required this.onPrimaryAction,
    this.compact = false,
  });

  final SubmissionFlowStatus submissionFlowStatus;
  final String? submissionStatusHint;
  final bool isUnsupportedProtocol;
  final bool requiresPracticeCompletion;
  final bool isPracticeCompleted;
  final String? selectedAudioLabel;
  final String? existingAudioLabel;
  final bool isSubmitting;
  final bool isRecording;
  final bool isSelectedAudioPlaying;
  final bool isSelectedAudioLoading;
  final bool isStoredAudioPlaying;
  final bool isStoredAudioLoading;
  final VoidCallback? onRecordAudio;
  final VoidCallback? onClearSelectedAudio;
  final VoidCallback? onPlaySelectedAudio;
  final VoidCallback? onPlayStoredAudio;
  final VoidCallback onPrimaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (submissionFlowStatus) {
      SubmissionFlowStatus.notStarted => isRecording ? '录音中' : '未提交',
      SubmissionFlowStatus.queued => '已提交',
      SubmissionFlowStatus.processing => '评分中',
      SubmissionFlowStatus.failed => isRecording ? '录音中' : '重试',
      SubmissionFlowStatus.completed => '已点评',
    };
    final statusColor = switch (submissionFlowStatus) {
      SubmissionFlowStatus.notStarted => const Color(0xFF2563EB),
      SubmissionFlowStatus.queued => const Color(0xFFF97316),
      SubmissionFlowStatus.processing => const Color(0xFFFF8F4D),
      SubmissionFlowStatus.failed => const Color(0xFFDC2626),
      SubmissionFlowStatus.completed => const Color(0xFF16A34A),
    };
    final requiresPracticeFirst =
        requiresPracticeCompletion && !isPracticeCompleted && !isRecording;
    final canSubmit =
        submissionFlowStatus == SubmissionFlowStatus.notStarted ||
        submissionFlowStatus == SubmissionFlowStatus.failed ||
        submissionFlowStatus == SubmissionFlowStatus.completed;
    final hasSelectedAudio = (selectedAudioLabel ?? '').trim().isNotEmpty;
    final trimmedStatusHint = submissionStatusHint?.trim();
    final (
      helperMessage,
      helperBackground,
      helperForeground,
      helperIcon,
    ) = switch (submissionFlowStatus) {
      _ when isUnsupportedProtocol => (
        '这道题型正在更新中，先点跳过继续下一句，系统会保留兜底能力。',
        const Color(0xFFFFF7E8),
        const Color(0xFFB45309),
        Icons.auto_fix_high_rounded,
      ),
      _ when requiresPracticeFirst => (
        '先完成上面的拼句练习，再开始录音或提交这一句。',
        const Color(0xFFFFF7E8),
        const Color(0xFFB45309),
        Icons.extension_rounded,
      ),
      _ when isRecording => (
        '读完后点结束录音，系统会自动帮你保存这一句。',
        const Color(0xFFFFE4E6),
        const Color(0xFFDC2626),
        Icons.graphic_eq_rounded,
      ),
      _ when hasSelectedAudio && !isSubmitting => (
        submissionFlowStatus == SubmissionFlowStatus.failed
            ? '上一回没有立刻传上去，这段录音还在，点一下就能重新提交。'
            : submissionFlowStatus == SubmissionFlowStatus.completed
            ? '这段录音已经准备好了，想挑战更高分的话可以再次提交。'
            : '录音已经准备好了，先试听一下，再点提交这一句。',
        const Color(0xFFEAFBF1),
        const Color(0xFF15803D),
        Icons.check_circle_rounded,
      ),
      SubmissionFlowStatus.queued when trimmedStatusHint != null => (
        trimmedStatusHint,
        const Color(0xFFFFF2E4),
        const Color(0xFFEA580C),
        Icons.schedule_rounded,
      ),
      SubmissionFlowStatus.processing when trimmedStatusHint != null => (
        trimmedStatusHint,
        const Color(0xFFFFF2E4),
        const Color(0xFFFF8F4D),
        Icons.auto_awesome_rounded,
      ),
      SubmissionFlowStatus.completed when trimmedStatusHint != null => (
        trimmedStatusHint,
        const Color(0xFFEAFBF1),
        const Color(0xFF16A34A),
        Icons.emoji_events_rounded,
      ),
      _ => (null, null, null, null),
    };
    final primaryLabel = isUnsupportedProtocol
        ? (compact ? '跳过' : '先跳过这一句')
        : requiresPracticeFirst
        ? (compact ? '先拼句' : '先完成拼句')
        : isRecording
        ? (compact ? '停止' : '结束录音')
        : hasSelectedAudio
        ? (isSubmitting
              ? (submissionFlowStatus == SubmissionFlowStatus.failed
                    ? '重交中'
                    : submissionFlowStatus == SubmissionFlowStatus.completed
                    ? '再交中'
                    : '提交中')
              : (submissionFlowStatus == SubmissionFlowStatus.failed
                    ? (compact ? '重交' : '重新提交')
                    : submissionFlowStatus == SubmissionFlowStatus.completed
                    ? (compact ? '再交' : '再次提交')
                    : (compact ? '提交' : '提交这一句')))
        : (compact ? '录音' : '开始录音');
    final submitLabel = submissionFlowStatus == SubmissionFlowStatus.failed
        ? (compact ? '重交' : '重新提交')
        : submissionFlowStatus == SubmissionFlowStatus.completed
        ? (compact ? '再交' : '再次提交')
        : (compact ? '提交' : '提交这一句');
    final primaryIcon = isUnsupportedProtocol
        ? Icons.skip_next_rounded
        : requiresPracticeFirst
        ? Icons.extension_rounded
        : isSubmitting
        ? null
        : isRecording
        ? Icons.stop_circle_rounded
        : hasSelectedAudio
        ? (submissionFlowStatus == SubmissionFlowStatus.failed
              ? Icons.refresh_rounded
              : submissionFlowStatus == SubmissionFlowStatus.completed
              ? Icons.restart_alt_rounded
              : Icons.cloud_upload_rounded)
        : Icons.mic_rounded;
    final primaryAction = isUnsupportedProtocol
        ? onPrimaryAction
        : requiresPracticeFirst
        ? null
        : isSubmitting
        ? null
        : isRecording
        ? onRecordAudio
        : hasSelectedAudio
        ? (canSubmit ? onPrimaryAction : null)
        : onRecordAudio;
    final recordButtonState = isSubmitting
        ? AudioRecordButtonState.processing
        : isRecording
        ? AudioRecordButtonState.recording
        : AudioRecordButtonState.idle;
    final showSplitActions =
        hasSelectedAudio &&
        !isRecording &&
        !isUnsupportedProtocol &&
        !requiresPracticeFirst;
    final dockTitle = isRecording
        ? '正在听你读'
        : hasSelectedAudio
        ? '录音已保存'
        : requiresPracticeFirst
        ? '先完成上面的练习'
        : isUnsupportedProtocol
        ? '这题先跳过'
        : '读完点录音';
    final dockSubtitle = isRecording
        ? '再次点击结束，系统会保存这一句。'
        : hasSelectedAudio
        ? '先试听，再提交生成 AI 点评结果。'
        : requiresPracticeFirst
        ? '完成拼句后，录音按钮会自动亮起。'
        : isUnsupportedProtocol
        ? '系统会保留进度，不影响继续学习。'
        : '一个长条按钮就够了，不需要找两个录音键。';
    final statusIcon = isRecording
        ? Icons.graphic_eq_rounded
        : hasSelectedAudio
        ? Icons.check_circle_rounded
        : Icons.mic_rounded;

    Widget primaryButton({required bool compactMode}) {
      return FilledButton.icon(
        onPressed: primaryAction,
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(compactMode ? 50 : 52),
          backgroundColor: const Color(0xFFFF8F4D),
          foregroundColor: Colors.white,
        ),
        icon: isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(primaryIcon),
        label: Text(primaryLabel),
      );
    }

    final helperWidget =
        helperMessage != null &&
            helperBackground != null &&
            helperForeground != null &&
            helperIcon != null
        ? _SubmissionHintBanner(
            message: helperMessage,
            backgroundColor: helperBackground,
            foregroundColor: helperForeground,
            icon: helperIcon,
          )
        : null;
    final detailWidgets = <Widget>[
      if (selectedAudioLabel != null)
        _SubmissionAudioCard(title: '录音已保存', fileName: selectedAudioLabel!),
      if (existingAudioLabel != null &&
          submissionFlowStatus != SubmissionFlowStatus.notStarted)
        _SubmissionAudioCard(
          title: '已提交给 AI 老师',
          fileName: existingAudioLabel!,
          onAction: onPlayStoredAudio,
          isPlaying: isStoredAudioPlaying,
          isLoading: isStoredAudioLoading,
        ),
    ];
    final controls = Column(
      children: [
        if (showSplitActions)
          _RecordedAudioActionRow(
            compact: compact,
            isSubmitting: isSubmitting,
            isPlaying: isSelectedAudioPlaying,
            isLoading: isSelectedAudioLoading,
            submitLabel: submitLabel,
            onPlay: onPlaySelectedAudio,
            onRecordAgain: onRecordAudio,
            onDelete: onClearSelectedAudio,
            onSubmit: canSubmit ? onPrimaryAction : null,
          )
        else
          AudioRecordButton(
            state: recordButtonState,
            onPressed: isUnsupportedProtocol || requiresPracticeFirst
                ? null
                : onRecordAudio,
            compact: compact,
          ),
        if (!showSplitActions &&
            (isUnsupportedProtocol || requiresPracticeFirst)) ...[
          const SizedBox(height: 10),
          primaryButton(compactMode: compact),
        ],
      ],
    );

    return PracticeControlDock(
      statusLabel: statusLabel,
      statusColor: statusColor,
      statusIcon: statusIcon,
      title: dockTitle,
      subtitle: dockSubtitle,
      helper: helperWidget,
      details: detailWidgets,
      controls: controls,
      compact: compact,
    );
  }
}

class _SubmissionAudioCard extends StatelessWidget {
  const _SubmissionAudioCard({
    required this.title,
    required this.fileName,
    this.onAction,
    this.isPlaying = false,
    this.isLoading = false,
  });

  final String title;
  final String fileName;
  final VoidCallback? onAction;
  final bool isPlaying;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.audio_file_rounded, color: Color(0xFF2FA77D)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: onAction,
              tooltip: isLoading ? '加载中' : (isPlaying ? '停止播放' : '播放录音'),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isPlaying
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_outline_rounded,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordedAudioActionRow extends StatelessWidget {
  const _RecordedAudioActionRow({
    required this.compact,
    required this.isSubmitting,
    required this.isPlaying,
    required this.isLoading,
    required this.submitLabel,
    required this.onSubmit,
    this.onPlay,
    this.onRecordAgain,
    this.onDelete,
  });

  final bool compact;
  final bool isSubmitting;
  final bool isPlaying;
  final bool isLoading;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final VoidCallback? onPlay;
  final VoidCallback? onRecordAgain;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final playLabel = isLoading ? '加载' : (isPlaying ? '停止' : '试听');
    final secondaryHeight = compact ? 48.0 : 52.0;
    final children = <Widget>[
      if (onPlay != null)
        _RecordedAudioPillButton(
          label: playLabel,
          icon: isLoading
              ? null
              : isPlaying
              ? Icons.stop_circle_rounded
              : Icons.play_circle_fill_rounded,
          onPressed: isSubmitting ? null : onPlay,
          isLoading: isLoading,
          height: secondaryHeight,
        ),
      _RecordedAudioPillButton(
        label: compact ? '重录' : '重录一次',
        icon: Icons.restart_alt_rounded,
        onPressed: isSubmitting ? null : onRecordAgain,
        height: secondaryHeight,
      ),
      if (onDelete != null && !compact)
        _RecordedAudioPillButton(
          label: '删除',
          icon: Icons.delete_outline_rounded,
          onPressed: isSubmitting ? null : onDelete,
          height: secondaryHeight,
          danger: true,
        ),
    ];

    return Row(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Flexible(child: children[index]),
        ],
        const SizedBox(width: 10),
        Expanded(
          flex: compact ? 2 : 3,
          child: FilledButton.icon(
            onPressed: isSubmitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(secondaryHeight),
              backgroundColor: const Color(0xFFFF8F4D),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFFFC4A3),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_rounded),
            label: Text(
              isSubmitting ? '提交中' : submitLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordedAudioPillButton extends StatelessWidget {
  const _RecordedAudioPillButton({
    required this.label,
    required this.height,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.danger = false,
  });

  final String label;
  final double height;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = danger
        ? const Color(0xFFDC2626)
        : const Color(0xFF2563EB);
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        foregroundColor: foregroundColor,
        backgroundColor: Colors.white,
        side: BorderSide(color: foregroundColor.withValues(alpha: 0.22)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foregroundColor,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SubmissionHintBanner extends StatelessWidget {
  const _SubmissionHintBanner({
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
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
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
