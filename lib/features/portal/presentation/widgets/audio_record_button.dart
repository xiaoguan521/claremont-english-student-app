import 'package:flutter/material.dart';

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
      duration: const Duration(milliseconds: 900),
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
        const Color(0xFFFF8F4D),
        Colors.white,
      ),
      AudioRecordButtonState.recording => (
        widget.compact ? '停止' : '结束录音',
        Icons.stop_circle_rounded,
        const Color(0xFFDC2626),
        Colors.white,
      ),
      AudioRecordButtonState.processing => (
        widget.compact ? '处理中' : '处理中',
        null,
        const Color(0xFF94A3B8),
        Colors.white,
      ),
      AudioRecordButtonState.done => (
        widget.compact ? '重录' : '重新录音',
        Icons.restart_alt_rounded,
        const Color(0xFF2563EB),
        Colors.white,
      ),
    };

    return FilledButton.icon(
      onPressed: widget.onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(widget.compact ? 50 : 52),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      ),
      icon: widget.state == AudioRecordButtonState.processing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : widget.state == AudioRecordButtonState.recording
          ? _RecordingPulseIcon(animation: _controller)
          : Icon(icon),
      label: Text(label),
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
            final height = 8.0 + (value * 8);
            return Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
              child: Container(
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
