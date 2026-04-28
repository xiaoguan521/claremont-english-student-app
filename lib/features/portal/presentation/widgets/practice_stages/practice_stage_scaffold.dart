import 'package:flutter/material.dart';

import '../../../../../core/ui/app_ui_tokens.dart';

class ListeningPlayerStage extends StatelessWidget {
  const ListeningPlayerStage({
    super.key,
    required this.header,
    required this.actionChips,
    required this.submissionDock,
    this.practiceRenderer,
  });

  final Widget header;
  final Widget actionChips;
  final Widget submissionDock;
  final Widget? practiceRenderer;

  @override
  Widget build(BuildContext context) {
    return PracticeStageScaffold(
      header: header,
      actionChips: actionChips,
      practiceRenderer: practiceRenderer,
      submissionDock: submissionDock,
      stageHint: '先安静听清楚，再做选择。',
      stageIcon: Icons.headphones_rounded,
    );
  }
}

class SequentialReadStage extends StatelessWidget {
  const SequentialReadStage({
    super.key,
    required this.header,
    required this.actionChips,
    required this.submissionDock,
    this.practiceRenderer,
  });

  final Widget header;
  final Widget actionChips;
  final Widget submissionDock;
  final Widget? practiceRenderer;

  @override
  Widget build(BuildContext context) {
    return PracticeStageScaffold(
      header: header,
      actionChips: actionChips,
      practiceRenderer: practiceRenderer,
      submissionDock: submissionDock,
      stageHint: '按顺序完成这一句，AI 老师会听你的发音。',
      stageIcon: Icons.record_voice_over_rounded,
    );
  }
}

class HotspotReadStage extends StatelessWidget {
  const HotspotReadStage({
    super.key,
    required this.header,
    required this.actionChips,
    required this.submissionDock,
    this.practiceRenderer,
  });

  final Widget header;
  final Widget actionChips;
  final Widget submissionDock;
  final Widget? practiceRenderer;

  @override
  Widget build(BuildContext context) {
    return PracticeStageScaffold(
      header: header,
      actionChips: actionChips,
      practiceRenderer: practiceRenderer,
      submissionDock: submissionDock,
      stageHint: '看图找线索，点到正确区域就能点亮这一题。',
      stageIcon: Icons.touch_app_rounded,
    );
  }
}

class PagedRecordStage extends StatelessWidget {
  const PagedRecordStage({
    super.key,
    required this.header,
    required this.actionChips,
    required this.submissionDock,
    this.practiceRenderer,
  });

  final Widget header;
  final Widget actionChips;
  final Widget submissionDock;
  final Widget? practiceRenderer;

  @override
  Widget build(BuildContext context) {
    return PracticeStageScaffold(
      header: header,
      actionChips: actionChips,
      practiceRenderer: practiceRenderer,
      submissionDock: submissionDock,
      stageHint: '先听原音，再录下你的声音。',
      stageIcon: Icons.mic_rounded,
    );
  }
}

class PracticeStageScaffold extends StatelessWidget {
  const PracticeStageScaffold({
    super.key,
    required this.header,
    required this.actionChips,
    required this.submissionDock,
    required this.stageHint,
    required this.stageIcon,
    this.practiceRenderer,
  });

  final Widget header;
  final Widget actionChips;
  final Widget submissionDock;
  final String stageHint;
  final IconData stageIcon;
  final Widget? practiceRenderer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: AppUiTokens.spaceSm),
        _PracticeStageHint(icon: stageIcon, label: stageHint),
        const SizedBox(height: AppUiTokens.spaceSm),
        actionChips,
        if (practiceRenderer != null) ...[
          const SizedBox(height: AppUiTokens.spaceSm),
          practiceRenderer!,
        ],
        const SizedBox(height: AppUiTokens.spaceMd - 2),
        submissionDock,
      ],
    );
  }
}

class _PracticeStageHint extends StatelessWidget {
  const _PracticeStageHint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppUiTokens.spaceSm,
        vertical: AppUiTokens.spaceXs + 1,
      ),
      decoration: BoxDecoration(
        color: AppUiTokens.studentSuccessSoft,
        borderRadius: BorderRadius.circular(AppUiTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppUiTokens.studentSuccess,
            size: 18,
          ),
          const SizedBox(width: AppUiTokens.spaceXs),
          Icon(icon, color: AppUiTokens.studentSuccess, size: 18),
          const SizedBox(width: AppUiTokens.spaceXs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppUiTokens.studentSuccess,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
