import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/practice_protocol_models.dart';

class PracticeRenderer extends StatelessWidget {
  const PracticeRenderer({
    required this.task,
    required this.state,
    this.onWordBankChanged,
    this.onListenChooseChanged,
    super.key,
  });

  final PracticeTaskProtocol task;
  final PracticeTaskState state;
  final ValueChanged<List<String>>? onWordBankChanged;
  final ValueChanged<String>? onListenChooseChanged;

  @override
  Widget build(BuildContext context) {
    final child = switch (task.type) {
      PracticeTaskType.audioRepeat => _AudioRepeatPreview(task: task),
      PracticeTaskType.wordBank => _WordBankPreview(
        task: task,
        state: state,
        onChanged: onWordBankChanged,
      ),
      PracticeTaskType.hotspotSelect => _HotspotPreview(
        task: task,
        state: state,
      ),
      PracticeTaskType.listenAndChoose => _ListenAndChoosePreview(
        task: task,
        state: state,
        onChanged: onListenChooseChanged,
      ),
      PracticeTaskType.unsupported => _UnsupportedPracticePreview(task: task),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAFBF1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: Color(0xFF16A34A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '练习方式预览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SyncBadge(status: state.syncStatus),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AudioRepeatPreview extends StatelessWidget {
  const _AudioRepeatPreview({required this.task});

  final PracticeTaskProtocol task;

  @override
  Widget build(BuildContext context) {
    final text = task.content['text'] as String? ?? task.prompt;
    return _PreviewCard(
      icon: Icons.mic_external_on_rounded,
      title: '听示范后跟读',
      subtitle: text,
      footer: '支持示范播放、录音、试听和再次提交。',
      accent: const Color(0xFFFF8F4D),
    );
  }
}

class _WordBankPreview extends StatelessWidget {
  const _WordBankPreview({
    required this.task,
    required this.state,
    this.onChanged,
  });

  final PracticeTaskProtocol task;
  final PracticeTaskState state;
  final ValueChanged<List<String>>? onChanged;

  @override
  Widget build(BuildContext context) {
    final sourceTokens =
        (task.content['tokens'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => '$item')
            .toList();
    final expectedTokens =
        (task.content['expectedTokens'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => '$item')
            .toList();
    final selectedTokens = state.selectedTokens;
    final availableTokens = _remainingWordBankTokens(
      sourceTokens,
      selectedTokens,
    );
    final isSolved =
        expectedTokens.isNotEmpty && listEquals(selectedTokens, expectedTokens);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewCard(
          icon: Icons.view_stream_rounded,
          title: '点击词块拼句',
          subtitle: task.prompt,
          footer: isSolved
              ? (task.feedback['successHint'] as String? ?? '你已经把句子拼对了。')
              : '第一版支持点击入槽和点击撤回。',
          accent: const Color(0xFF2563EB),
        ),
        if (selectedTokens.isNotEmpty) ...[
          const SizedBox(height: 12),
          _WordBankSelectedTray(
            tokens: selectedTokens,
            isSolved: isSolved,
            onTokenTap: onChanged == null
                ? null
                : (index) {
                    final nextTokens = List<String>.from(selectedTokens)
                      ..removeAt(index);
                    onChanged!(nextTokens);
                  },
          ),
        ],
        if (sourceTokens.isNotEmpty) ...[
          const SizedBox(height: 12),
          _WordBankAvailableTokens(
            tokens: availableTokens,
            onTokenTap: onChanged == null
                ? null
                : (token) {
                    final nextTokens = List<String>.from(selectedTokens)
                      ..add(token);
                    onChanged!(nextTokens);
                  },
          ),
        ],
      ],
    );
  }
}

class _WordBankSelectedTray extends StatelessWidget {
  const _WordBankSelectedTray({
    required this.tokens,
    required this.isSolved,
    this.onTokenTap,
  });

  final List<String> tokens;
  final bool isSolved;
  final ValueChanged<int>? onTokenTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSolved
        ? const Color(0xFF16A34A)
        : const Color(0xFF93C5FD);
    final backgroundColor = isSolved
        ? const Color(0xFFECFDF5)
        : const Color(0xFFEFF6FF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var index = 0; index < tokens.length; index += 1)
            _WordBankTokenChip(
              label: tokens[index],
              isSelected: true,
              onTap: onTokenTap == null ? null : () => onTokenTap!(index),
            ),
        ],
      ),
    );
  }
}

class _WordBankAvailableTokens extends StatelessWidget {
  const _WordBankAvailableTokens({required this.tokens, this.onTokenTap});

  final List<String> tokens;
  final ValueChanged<String>? onTokenTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tokens
          .map(
            (token) => _WordBankTokenChip(
              label: token,
              onTap: onTokenTap == null ? null : () => onTokenTap!(token),
            ),
          )
          .toList(),
    );
  }
}

class _WordBankTokenChip extends StatelessWidget {
  const _WordBankTokenChip({
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFDBEAFE) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFFD8E4F5),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF1E293B),
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: child,
    );
  }
}

class _HotspotPreview extends StatelessWidget {
  const _HotspotPreview({required this.task, required this.state});

  final PracticeTaskProtocol task;
  final PracticeTaskState state;

  @override
  Widget build(BuildContext context) {
    final pageNumber = task.content['pageNumber'];
    return _PreviewCard(
      icon: Icons.touch_app_rounded,
      title: '教材热区选词',
      subtitle: '在教材第 $pageNumber 页点击正确区域完成选择。',
      footer: state.isCompleted
          ? '这道热区题已经完成，可以继续下一句。'
          : '到教材图上点击正确热区后，这一句会自动标记完成。',
      accent: const Color(0xFF16A34A),
    );
  }
}

class _ListenAndChoosePreview extends StatelessWidget {
  const _ListenAndChoosePreview({
    required this.task,
    required this.state,
    this.onChanged,
  });

  final PracticeTaskProtocol task;
  final PracticeTaskState state;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final options =
        (task.content['options'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => '$item')
            .where((item) => item.isNotEmpty)
            .toList();
    final correctOption = task.content['correctOption'] as String?;
    final selectedValue = state.selectedValue;
    final isSolved =
        correctOption != null &&
        correctOption.isNotEmpty &&
        selectedValue == correctOption;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewCard(
          icon: Icons.hearing_rounded,
          title: '听音后选择',
          subtitle: task.prompt,
          footer: isSolved
              ? (task.feedback['successHint'] as String? ?? '你已经选对了。')
              : '适合听音选图、听音选项和自然拼读类题目。',
          accent: const Color(0xFF0EA5E9),
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChoiceOptionTile(
                label: option,
                isSelected: selectedValue == option,
                isCorrect: correctOption == option && isSolved,
                onTap: onChanged == null ? null : () => onChanged!(option),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceOptionTile extends StatelessWidget {
  const _ChoiceOptionTile({
    required this.label,
    this.isSelected = false,
    this.isCorrect = false,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isCorrect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isCorrect
        ? const Color(0xFF16A34A)
        : isSelected
        ? const Color(0xFF0EA5E9)
        : const Color(0xFFDCE7E3);
    final backgroundColor = isCorrect
        ? const Color(0xFFECFDF5)
        : isSelected
        ? const Color(0xFFE0F2FE)
        : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _UnsupportedPracticePreview extends StatelessWidget {
  const _UnsupportedPracticePreview({required this.task});

  final PracticeTaskProtocol task;

  @override
  Widget build(BuildContext context) {
    return _PreviewCard(
      icon: Icons.warning_amber_rounded,
      title: '当前题型预留中',
      subtitle: task.prompt,
      footer: '这个题型暂时还没有接入正式渲染器，学生端会继续保留兜底能力。',
      accent: const Color(0xFFF97316),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String footer;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            footer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.status});

  final PracticeTaskSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background) = switch (status) {
      PracticeTaskSyncStatus.idle => (
        '待开始',
        const Color(0xFF475569),
        const Color(0xFFF1F5F9),
      ),
      PracticeTaskSyncStatus.pending => (
        '待同步',
        const Color(0xFFB45309),
        const Color(0xFFFFF7ED),
      ),
      PracticeTaskSyncStatus.syncing => (
        '同步中',
        const Color(0xFF0369A1),
        const Color(0xFFE0F2FE),
      ),
      PracticeTaskSyncStatus.synced => (
        '已同步',
        const Color(0xFF15803D),
        const Color(0xFFECFDF5),
      ),
      PracticeTaskSyncStatus.failed => (
        '待重试',
        const Color(0xFFDC2626),
        const Color(0xFFFFF1F2),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

List<String> _remainingWordBankTokens(
  List<String> sourceTokens,
  List<String> selectedTokens,
) {
  final selectedCounts = <String, int>{};
  for (final token in selectedTokens) {
    selectedCounts.update(token, (value) => value + 1, ifAbsent: () => 1);
  }

  final remaining = <String>[];
  for (final token in sourceTokens) {
    final usedCount = selectedCounts[token] ?? 0;
    if (usedCount > 0) {
      selectedCounts[token] = usedCount - 1;
      continue;
    }
    remaining.add(token);
  }
  return remaining;
}
