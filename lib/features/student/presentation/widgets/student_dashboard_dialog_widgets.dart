import 'package:flutter/material.dart';

class StudentReviewFeedItem {
  const StudentReviewFeedItem({
    required this.title,
    required this.tag,
    required this.belongTo,
    required this.teacher,
    required this.dateLabel,
    this.highlighted = false,
    this.onTap,
  });

  final String title;
  final String tag;
  final String belongTo;
  final String teacher;
  final String dateLabel;
  final bool highlighted;
  final VoidCallback? onTap;
}

class StudentReviewFeed extends StatelessWidget {
  const StudentReviewFeed({super.key, required this.items});

  final List<StudentReviewFeedItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ReviewFeedCard(item: items[index]),
    );
  }
}

class StudentTaskCenterItem {
  const StudentTaskCenterItem({
    required this.title,
    required this.target,
    required this.range,
    required this.status,
    required this.actionLabel,
  });

  final String title;
  final String target;
  final String range;
  final String status;
  final String actionLabel;
}

class StudentTaskCenterFeed extends StatelessWidget {
  const StudentTaskCenterFeed({super.key, required this.items});

  final List<StudentTaskCenterItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _TaskCenterCard(item: items[index]),
    );
  }
}

class StudentSchoolDynamicItem {
  const StudentSchoolDynamicItem({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String content;
  final Color color;
}

class StudentSchoolDynamicPanel extends StatelessWidget {
  const StudentSchoolDynamicPanel({
    super.key,
    required this.schoolName,
    required this.primaryColor,
    required this.items,
    this.isCompact = false,
    this.showHeading = true,
  });

  final String schoolName;
  final Color primaryColor;
  final List<StudentSchoolDynamicItem> items;
  final bool isCompact;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 20 : 24),
      decoration: _studentPlasticPanelDecoration(
        accent: const Color(0xFF78E55A),
        radius: 30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeading) ...[
            Text(
              '班级动态',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: primaryColor,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '班级动态 · 英语',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(item.icon, color: item.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFF17335F),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                        ),
                      ],
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

class StudentProfileAction {
  const StudentProfileAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;
}

class StudentProfileDialogContent extends StatelessWidget {
  const StudentProfileDialogContent({
    super.key,
    required this.displayName,
    required this.emailLabel,
    required this.progressLabel,
    required this.actions,
    this.useStacked = false,
  });

  final String displayName;
  final String emailLabel;
  final String progressLabel;
  final List<StudentProfileAction> actions;
  final bool useStacked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(useStacked ? 16 : 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE9F8FF), Color(0xFFFFF4CC)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Container(
                width: useStacked ? 58 : 72,
                height: useStacked ? 58 : 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(useStacked ? 20 : 24),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF44618F),
                  size: 38,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFF17335F),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emailLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      progressLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF1D5EA8),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: useStacked ? 2 : 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: useStacked ? 1.65 : 1.15,
            ),
            itemBuilder: (context, index) =>
                _StudentProfileActionCard(data: actions[index]),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '个人中心只保留孩子最常用的入口，其他学习内容回到学习地图中探索。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class StudentInfoLine extends StatelessWidget {
  const StudentInfoLine({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF2472D8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );
  }
}

class StudentStarCoinLedgerRow extends StatelessWidget {
  const StudentStarCoinLedgerRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF17335F),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              amount,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentMessageCenterContent extends StatelessWidget {
  const StudentMessageCenterContent({
    super.key,
    required this.pendingTasks,
    this.activityTitle,
    this.className,
    this.onOpenReviewCenter,
  });

  final int pendingTasks;
  final String? activityTitle;
  final String? className;
  final VoidCallback? onOpenReviewCenter;

  static const List<String> _categories = [
    '老师点评',
    '学校通知',
    '班级通知',
    '任务提醒',
    '课程提醒',
    '请假提醒',
    '其他消息',
  ];

  @override
  Widget build(BuildContext context) {
    final canOpenReviewCenter =
        activityTitle != null &&
        className != null &&
        onOpenReviewCenter != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useStacked = constraints.maxWidth < 940;
        final categoryRail = _MessageCategoryRail(
          categories: _categories,
          useStacked: useStacked,
        );
        final messageBody = Container(
          decoration: const BoxDecoration(
            color: Color(0xFFEAF5FF),
            borderRadius: BorderRadius.all(Radius.circular(30)),
          ),
          child: canOpenReviewCenter
              ? Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TeacherReviewMessageCard(
                        activityTitle: activityTitle!,
                        className: className!,
                        onTap: onOpenReviewCenter!,
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: _EmptyMessageState(pendingTasks: pendingTasks),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _EmptyMessageState(pendingTasks: pendingTasks),
                  ),
                ),
        );

        if (useStacked) {
          return Column(
            children: [
              categoryRail,
              const SizedBox(height: 16),
              Expanded(child: messageBody),
            ],
          );
        }

        return Row(
          children: [
            categoryRail,
            const SizedBox(width: 18),
            Expanded(child: messageBody),
          ],
        );
      },
    );
  }
}

class _StudentProfileActionCard extends StatelessWidget {
  const _StudentProfileActionCard({required this.data});

  final StudentProfileAction data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(data.icon, color: data.accent, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF17335F),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCategoryRail extends StatelessWidget {
  const _MessageCategoryRail({
    required this.categories,
    required this.useStacked,
  });

  final List<String> categories;
  final bool useStacked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: useStacked ? double.infinity : 260,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: useStacked
          ? Wrap(
              spacing: 12,
              runSpacing: 12,
              children: categories.asMap().entries.map((entry) {
                return _MessageCategoryPill(
                  label: entry.value,
                  selected: entry.key == 0,
                  compact: true,
                );
              }).toList(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: categories.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MessageCategoryPill(
                    label: entry.value,
                    selected: entry.key == 0,
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _MessageCategoryPill extends StatelessWidget {
  const _MessageCategoryPill({
    required this.label,
    required this.selected,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 18,
        vertical: compact ? 14 : 16,
      ),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFDCEBFF)
            : compact
            ? const Color(0xFFF4F8FF)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
      ),
      child: Text(
        label,
        style:
            (compact
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.titleLarge)
                ?.copyWith(
                  color: selected
                      ? const Color(0xFF2160D4)
                      : const Color(0xFF1E293B),
                  fontWeight: FontWeight.w800,
                ),
      ),
    );
  }
}

class _TeacherReviewMessageCard extends StatelessWidget {
  const _TeacherReviewMessageCard({
    required this.activityTitle,
    required this.className,
    required this.onTap,
  });

  final String activityTitle;
  final String className;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF2E3), Color(0xFFEAF7FF)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.82),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFA24A).withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.rate_review_rounded,
                  color: Color(0xFFFF8A3D),
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '老师点评',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFF17335F),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '查看老师反馈、AI 诊断和发音建议',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$className · $activityTitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF2E7BEF),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B4A),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '去查看',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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

class _EmptyMessageState extends StatelessWidget {
  const _EmptyMessageState({required this.pendingTasks});

  final int pendingTasks;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFFBCC8D9),
              size: 44,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '暂无学校通知',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF6B7A90),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '当前待完成任务 $pendingTasks 项，新的消息会在这里提醒你。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewFeedCard extends StatelessWidget {
  const _ReviewFeedCard({required this.item});

  final StudentReviewFeedItem item;

  @override
  Widget build(BuildContext context) {
    final unread = item.highlighted;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF17335F),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (unread) const _UnreadDot(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.belongTo,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaChip(icon: Icons.mic_rounded, label: item.tag),
                _MetaChip(icon: Icons.person_rounded, label: item.teacher),
                _MetaChip(
                  icon: Icons.schedule_rounded,
                  label: item.dateLabel.replaceAll('\n', ' '),
                ),
              ],
            ),
          ],
        );

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: unread ? const Color(0xFFEAF5FF) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: unread
                      ? const Color(0xFF93C5FD).withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF94B8F3).withValues(alpha: 0.1),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReviewThumbnail(title: item.title, unread: unread),
                        const SizedBox(height: 14),
                        content,
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _ActionChip(
                            label: unread ? '看新点评' : '查看点评',
                            highlighted: unread,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Flexible(
                          flex: 2,
                          child: _ReviewThumbnail(
                            title: item.title,
                            unread: unread,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 7, child: content),
                        const SizedBox(width: 14),
                        Flexible(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _ActionChip(
                              label: unread ? '看新点评' : '查看点评',
                              highlighted: unread,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _TaskCenterCard extends StatelessWidget {
  const _TaskCenterCard({required this.item});

  final StudentTaskCenterItem item;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final cover = AspectRatio(
          aspectRatio: compact ? 1.25 : 1.38,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF5D2), Color(0xFFFFD27C)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.edit_calendar_rounded,
              size: 42,
              color: Color(0xFFCC7B00),
            ),
          ),
        );
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF1F315B),
                fontWeight: FontWeight.w900,
                height: 1.28,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetaChip(icon: Icons.groups_rounded, label: item.target),
                _MetaChip(icon: Icons.date_range_rounded, label: item.range),
                _TaskStatusPill(status: item.status),
              ],
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.status == '可补做'
                ? const Color(0xFFFFF7E8)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: item.status == '可补做'
                  ? const Color(0xFFFFD5A8)
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cover,
                    const SizedBox(height: 14),
                    content,
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ActionChip(
                        label: item.actionLabel,
                        highlighted: item.status == '可补做',
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Flexible(flex: 2, child: cover),
                    const SizedBox(width: 16),
                    Expanded(flex: 7, child: content),
                    const SizedBox(width: 16),
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _ActionChip(
                          label: item.actionLabel,
                          highlighted: item.status == '可补做',
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ReviewThumbnail extends StatelessWidget {
  const _ReviewThumbnail({required this.title, required this.unread});

  final String title;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final isSong = title.toLowerCase().contains('song');
    final isPhonics = title.toLowerCase().contains('phonics');
    final icon = isSong
        ? Icons.music_note_rounded
        : isPhonics
        ? Icons.abc_rounded
        : Icons.auto_stories_rounded;
    return AspectRatio(
      aspectRatio: 1.38,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: unread
                ? const [Color(0xFFFFF0C2), Color(0xFFFFB36B)]
                : const [Color(0xFFE9F8FF), Color(0xFFBDEBFF)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconSize = (constraints.biggest.shortestSide * 0.52).clamp(
              34.0,
              44.0,
            );
            return Stack(
              children: [
                Positioned(
                  right: -constraints.maxWidth * 0.12,
                  top: -constraints.maxHeight * 0.14,
                  child: Container(
                    width: constraints.maxHeight * 0.64,
                    height: constraints.maxHeight * 0.64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: unread
                        ? const Color(0xFFB45309)
                        : const Color(0xFF2472D8),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF3377D6), size: 17),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF1F315B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: highlighted
                ? const Color(0xFFFFE8E0)
                : const Color(0xFFEAF4FF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFFF8F4D).withValues(alpha: 0.26)
                  : const Color(0xFF2D8DFF).withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                highlighted
                    ? Icons.mark_chat_unread_rounded
                    : Icons.manage_search_rounded,
                color: highlighted
                    ? const Color(0xFFE85D2A)
                    : const Color(0xFF2C66D5),
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: highlighted
                      ? const Color(0xFF9A3F17)
                      : const Color(0xFF2C66D5),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (highlighted)
          const Positioned(right: -2, top: -2, child: _UnreadDot()),
      ],
    );
  }
}

class _TaskStatusPill extends StatelessWidget {
  const _TaskStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (status) {
      '可补做' => (
        const Color(0xFFFFF2E4),
        const Color(0xFFEA580C),
        Icons.replay_rounded,
      ),
      '已点评' => (
        const Color(0xFFEAF4FF),
        const Color(0xFF2C66D5),
        Icons.mark_chat_read_rounded,
      ),
      '已完成' => (
        const Color(0xFFEAFBF1),
        const Color(0xFF16A34A),
        Icons.check_circle_rounded,
      ),
      _ => (
        const Color(0xFFF1F5F9),
        const Color(0xFF64748B),
        Icons.flag_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 6),
          Text(
            status,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
        color: Color(0xFFFF4A3D),
        shape: BoxShape.circle,
      ),
    );
  }
}

BoxDecoration _studentPlasticPanelDecoration({
  Color accent = const Color(0xFF69C6FF),
  double radius = 30,
}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.9),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.72), width: 1.6),
    boxShadow: [
      BoxShadow(
        color: accent.withValues(alpha: 0.18),
        blurRadius: 18,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
