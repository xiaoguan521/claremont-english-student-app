import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

import '../../../student/presentation/widgets/student_ui_components.dart';
import '../widgets/tablet_shell.dart';

class ReviewDetailPage extends StatefulWidget {
  const ReviewDetailPage({
    super.key,
    required this.reviewId,
    required this.title,
    required this.belongTo,
    required this.teacher,
  });

  final String reviewId;
  final String title;
  final String belongTo;
  final String teacher;

  @override
  State<ReviewDetailPage> createState() => _ReviewDetailPageState();
}

class _ReviewDetailPageState extends State<ReviewDetailPage> {
  final FlutterTts _tts = FlutterTts();
  _ReviewAudioCue? _playingCue;

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(_clearPlayingCue);
    _tts.setCancelHandler(_clearPlayingCue);
    _tts.setErrorHandler((_) => _clearPlayingCue());
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _clearPlayingCue() {
    if (!mounted) {
      return;
    }
    setState(() {
      _playingCue = null;
    });
  }

  Future<void> _playCue(_ReviewAudioCue cue) async {
    if (_playingCue == cue) {
      await _tts.stop();
      _clearPlayingCue();
      return;
    }

    final spec = _audioSpec(cue);
    setState(() {
      _playingCue = cue;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(spec.message),
        duration: const Duration(milliseconds: 900),
      ),
    );
    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(spec.rate);
    await _tts.setPitch(spec.pitch);
    await _tts.awaitSpeakCompletion(true);
    await _tts.speak(spec.text);
  }

  _ReviewAudioSpec _audioSpec(_ReviewAudioCue cue) {
    return switch (cue) {
      _ReviewAudioCue.studentSentence => const _ReviewAudioSpec(
        text: 'I have got six dirty ears.',
        message: '正在播放学生录音回放',
        pitch: 0.9,
        rate: 0.42,
      ),
      _ReviewAudioCue.referenceSentence => const _ReviewAudioSpec(
        text: 'I have got six dirty ears.',
        message: '正在播放原音示范',
        pitch: 1.05,
        rate: 0.38,
      ),
      _ReviewAudioCue.referenceWord => const _ReviewAudioSpec(
        text: 'dirty',
        message: '正在播放 dirty 的原音示范',
        pitch: 1.05,
        rate: 0.32,
      ),
      _ReviewAudioCue.studentWord => const _ReviewAudioSpec(
        text: 'dirty',
        message: '正在回放你的 dirty 发音',
        pitch: 0.82,
        rate: 0.3,
      ),
    };
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/reviews');
    }
  }

  void _handleSwipeBack(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -520) {
      _goBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    final heroCard = _ReviewHeroCard(
      title: widget.title,
      belongTo: widget.belongTo,
      teacher: widget.teacher,
    );
    final sentenceCard = _PronunciationSentenceCard(
      reviewId: widget.reviewId,
      playingCue: _playingCue,
      onPlayCue: _playCue,
    );
    const teacherCard = _TeacherMessageCard();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _handleSwipeBack,
      child: TabletShell(
        activeSection: TabletSection.teaching,
        title: '查看点评',
        subtitle: '听得见、看得懂的发音反馈',
        theme: TabletShellTheme.k12Sky,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 760;

            if (isCompact) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(height: 300, child: heroCard),
                    const SizedBox(height: 16),
                    SizedBox(height: 520, child: sentenceCard),
                    const SizedBox(height: 16),
                    const SizedBox(height: 300, child: teacherCard),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    flex: 42,
                    child: Column(
                      children: [
                        Expanded(child: heroCard),
                        const SizedBox(height: 16),
                        const Expanded(child: teacherCard),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(flex: 58, child: sentenceCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _ReviewAudioCue {
  studentSentence,
  referenceSentence,
  referenceWord,
  studentWord,
}

class _ReviewAudioSpec {
  const _ReviewAudioSpec({
    required this.text,
    required this.message,
    required this.pitch,
    required this.rate,
  });

  final String text;
  final String message;
  final double pitch;
  final double rate;
}

class _ReviewHeroCard extends StatelessWidget {
  const _ReviewHeroCard({
    required this.title,
    required this.belongTo,
    required this.teacher,
  });

  final String title;
  final String belongTo;
  final String teacher;

  @override
  Widget build(BuildContext context) {
    return StudentGlassPanel(
      padding: const EdgeInsets.all(20),
      radius: 34,
      opacity: 0.18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBD9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '83 分',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFF97316),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF17335F),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            belongTo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF547089),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const _ScoreChip(label: '发音 82', color: Color(0xFF2E7BEF)),
              const _ScoreChip(label: '流利 86', color: Color(0xFF16A34A)),
              const _ScoreChip(label: '语调 78', color: Color(0xFFF97316)),
              _ScoreChip(label: teacher, color: const Color(0xFF8B5CF6)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PronunciationSentenceCard extends StatelessWidget {
  const _PronunciationSentenceCard({
    required this.reviewId,
    required this.playingCue,
    required this.onPlayCue,
  });

  final String reviewId;
  final _ReviewAudioCue? playingCue;
  final ValueChanged<_ReviewAudioCue> onPlayCue;

  @override
  Widget build(BuildContext context) {
    final words = [
      const _WordFeedback('I\'ve', _WordFeedbackLevel.good),
      const _WordFeedback('got', _WordFeedbackLevel.good),
      const _WordFeedback('six', _WordFeedbackLevel.good),
      const _WordFeedback('dirty', _WordFeedbackLevel.needsWork),
      const _WordFeedback('ears.', _WordFeedbackLevel.ok),
    ];

    return StudentBoundarylessSectionStage(
      icon: Icons.graphic_eq_rounded,
      title: 'AI 诊断报告',
      hint: '点击红色单词听对比',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '这句哪里需要注意？',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF17335F),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: words
                  .map(
                    (word) => _WordFeedbackChip(
                      word: word,
                      onTap: word.level == _WordFeedbackLevel.needsWork
                          ? () => _showWordFeedback(context, word.text)
                          : null,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            _PlaybackDock(
              reviewId: reviewId,
              playingCue: playingCue,
              onPlayStudent: () => onPlayCue(_ReviewAudioCue.studentSentence),
              onPlayReference: () =>
                  onPlayCue(_ReviewAudioCue.referenceSentence),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  const metrics = [
                    _MetricData('发音准确', 0.82, Color(0xFF2E7BEF)),
                    _MetricData('语速流利', 0.86, Color(0xFF16A34A)),
                    _MetricData('语调自然', 0.78, Color(0xFFF97316)),
                  ];
                  return compact
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: metrics
                              .map((metric) => _MetricBar(metric: metric))
                              .toList(),
                        )
                      : Row(
                          children: [
                            const Expanded(
                              flex: 4,
                              child: _MetricRadar(metrics: metrics),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: metrics
                                    .map((metric) => _MetricBar(metric: metric))
                                    .toList(),
                              ),
                            ),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWordFeedback(BuildContext context, String word) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              word,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(0xFFE85D2A),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '这个单词尾音需要更清楚一点。先听原音，再听自己的发音对比。',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onPlayCue(_ReviewAudioCue.referenceWord),
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('听原音示范'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onPlayCue(_ReviewAudioCue.studentWord),
                    icon: const Icon(Icons.mic_rounded),
                    label: const Text('听我的发音'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackDock extends StatelessWidget {
  const _PlaybackDock({
    required this.reviewId,
    required this.playingCue,
    required this.onPlayStudent,
    required this.onPlayReference,
  });

  final String reviewId;
  final _ReviewAudioCue? playingCue;
  final VoidCallback onPlayStudent;
  final VoidCallback onPlayReference;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: onPlayStudent,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2E7BEF),
              foregroundColor: Colors.white,
            ),
            icon: Icon(
              playingCue == _ReviewAudioCue.studentSentence
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: playingCue == null
                    ? (reviewId.hashCode.isEven ? 0.42 : 0.58)
                    : null,
                minHeight: 9,
                backgroundColor: Colors.white,
                color: const Color(0xFF2E7BEF),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onPlayReference,
            icon: Icon(
              playingCue == _ReviewAudioCue.referenceSentence
                  ? Icons.stop_rounded
                  : Icons.compare_arrows_rounded,
            ),
            label: Text(
              playingCue == _ReviewAudioCue.referenceSentence ? '停止原音' : '原音对比',
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherMessageCard extends StatelessWidget {
  const _TeacherMessageCard();

  @override
  Widget build(BuildContext context) {
    return StudentGlassPanel(
      padding: const EdgeInsets.all(20),
      radius: 34,
      opacity: 0.16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudentSectionPill(
            icon: Icons.mark_chat_read_rounded,
            label: '老师寄语',
          ),
          const SizedBox(height: 16),
          Text(
            '你今天朗读得很认真，整体很流畅。注意把 dirty 的尾音读完整，下一次会更自然。',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4CC),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '点评页只负责看反馈，不放“再练一次”，避免学习路径来回跳。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8A4F00),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

enum _WordFeedbackLevel { good, ok, needsWork }

class _WordFeedback {
  const _WordFeedback(this.text, this.level);

  final String text;
  final _WordFeedbackLevel level;
}

class _WordFeedbackChip extends StatelessWidget {
  const _WordFeedbackChip({required this.word, this.onTap});

  final _WordFeedback word;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (word.level) {
      _WordFeedbackLevel.good => (
        const Color(0xFFEAFBF1),
        const Color(0xFF16A34A),
        const Color(0xFFBBF7D0),
      ),
      _WordFeedbackLevel.ok => (
        const Color(0xFFFFF4CC),
        const Color(0xFFB45309),
        const Color(0xFFFDE68A),
      ),
      _WordFeedbackLevel.needsWork => (
        const Color(0xFFFFE8E0),
        const Color(0xFFE85D2A),
        const Color(0xFFFFB199),
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                word.level == _WordFeedbackLevel.needsWork
                    ? Icons.error_rounded
                    : Icons.check_circle_rounded,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 7),
              Text(
                word.text,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _MetricRadar extends StatelessWidget {
  const _MetricRadar({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox.square(
            dimension: size.clamp(120.0, 190.0),
            child: CustomPaint(painter: _MetricRadarPainter(metrics: metrics)),
          ),
        );
      },
    );
  }
}

class _MetricRadarPainter extends CustomPainter {
  const _MetricRadarPainter({required this.metrics});

  final List<_MetricData> metrics;

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.isEmpty) {
      return;
    }
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 18;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFB9D8F7);
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFB9D8F7).withValues(alpha: 0.72);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF2E7BEF).withValues(alpha: 0.22);
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF2E7BEF);

    for (final scale in const [0.33, 0.66, 1.0]) {
      canvas.drawPath(
        _radarPath(center, radius * scale, List.filled(metrics.length, 1)),
        gridPaint,
      );
    }

    for (var index = 0; index < metrics.length; index += 1) {
      final point = _pointFor(center, radius, index, metrics.length);
      canvas.drawLine(center, point, axisPaint);
    }

    final valuePath = _radarPath(
      center,
      radius,
      metrics.map((metric) => metric.value.clamp(0, 1).toDouble()).toList(),
    );
    canvas.drawPath(valuePath, fillPaint);
    canvas.drawPath(valuePath, strokePaint);

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < metrics.length; index += 1) {
      dotPaint.color = metrics[index].color;
      final point = _pointFor(
        center,
        radius * metrics[index].value.clamp(0, 1),
        index,
        metrics.length,
      );
      canvas.drawCircle(point, 4.5, dotPaint);
    }
  }

  Path _radarPath(Offset center, double radius, List<double> values) {
    final path = Path();
    for (var index = 0; index < values.length; index += 1) {
      final point = _pointFor(
        center,
        radius * values[index],
        index,
        values.length,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Offset _pointFor(Offset center, double radius, int index, int total) {
    final angle = -math.pi / 2 + (math.pi * 2 * index / total);
    return Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
  }

  @override
  bool shouldRepaint(covariant _MetricRadarPainter oldDelegate) {
    return oldDelegate.metrics != metrics;
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF17335F),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: metric.value,
            minHeight: 14,
            backgroundColor: const Color(0xFFE5F2FF),
            color: metric.color,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(metric.value * 100).round()}%',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: metric.color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
