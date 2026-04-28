import 'package:flutter/material.dart';

import '../../../../core/ui/app_ui_tokens.dart';

enum AudioRecordButtonState { idle, recording, processing, done }

class AudioRecordButton extends StatefulWidget {
  const AudioRecordButton({
    required this.state,
    this.onPressed,
    this.compact = false,
    super.key,
  });

  final AudioRecordButtonState state;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  State<AudioRecordButton> createState() => _AudioRecordButtonState();
}

class _AudioRecordButtonState extends State<AudioRecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppUiTokens.motionPulse,
    );
    _syncAnimationState();
  }

  @override
  void didUpdateWidget(covariant AudioRecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _syncAnimationState();
    }
  }

  void _syncAnimationState() {
    if (widget.state == AudioRecordButtonState.recording) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (
      label,
      icon,
      backgroundColor,
      foregroundColor,
    ) = switch (widget.state) {
      AudioRecordButtonState.idle => (
        widget.compact ? '录音' : '开始录音',
        Icons.mic_rounded,
        AppUiTokens.studentAccentOrange,
        Colors.white,
      ),
      AudioRecordButtonState.recording => (
        widget.compact ? '停止' : '结束录音',
        Icons.stop_circle_rounded,
        AppUiTokens.studentDanger,
        Colors.white,
      ),
      AudioRecordButtonState.processing => (
        widget.compact ? '处理中' : '处理中',
        null,
        AppUiTokens.studentDisabled,
        Colors.white,
      ),
      AudioRecordButtonState.done => (
        widget.compact ? '重录' : '重新录音',
        Icons.restart_alt_rounded,
        AppUiTokens.studentInfo,
        Colors.white,
      ),
    };

    return FilledButton(
      onPressed: widget.onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(
          widget.compact
              ? AppUiTokens.recordButtonCompactHeight
              : AppUiTokens.recordButtonHeight,
        ),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: backgroundColor.withValues(alpha: 0.52),
        disabledForegroundColor: foregroundColor.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUiTokens.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppUiTokens.spaceLg - 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.state == AudioRecordButtonState.processing)
            const SizedBox(
              width: AppUiTokens.iconSm,
              height: AppUiTokens.iconSm,
              child: CircularProgressIndicator(
                strokeWidth: AppUiTokens.progressStrokeSm,
                color: Colors.white,
              ),
            )
          else if (widget.state == AudioRecordButtonState.recording)
            _RecordingPulseIcon(animation: _controller)
          else
            Icon(icon),
          const SizedBox(width: AppUiTokens.spaceSm - 2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingPulseIcon extends StatelessWidget {
  const _RecordingPulseIcon({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.18;
            final value = (animation.value - delay).clamp(0.0, 1.0);
            final height = AppUiTokens.spaceXs + (value * AppUiTokens.spaceXs);
            return Padding(
              padding: EdgeInsets.only(
                right: index == 2 ? 0 : AppUiTokens.space2xs - 1,
              ),
              child: Container(
                width: AppUiTokens.space2xs,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppUiTokens.radiusPill),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
