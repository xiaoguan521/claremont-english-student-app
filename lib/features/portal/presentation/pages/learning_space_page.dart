import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_ui_tokens.dart';
import '../../../student/presentation/widgets/student_ui_components.dart';
import '../widgets/tablet_shell.dart';

class LearningSpacePage extends StatefulWidget {
  const LearningSpacePage({super.key, required this.spaceId});

  final String spaceId;

  @override
  State<LearningSpacePage> createState() => _LearningSpacePageState();
}

class _LearningSpacePageState extends State<LearningSpacePage> {
  final Set<String> _selectedActionTitles = <String>{};

  @override
  Widget build(BuildContext context) {
    final content = _LearningSpaceContent.fromId(widget.spaceId);
    return TabletShell(
      activeSection: TabletSection.explore,
      title: content.title,
      subtitle: content.subtitle,
      theme: TabletShellTheme.k12Sky,
      child: Padding(
        padding: const EdgeInsets.all(AppUiTokens.spaceLg),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth <
                AppUiTokens.studentLearningSpaceCompactBreakpoint;
            final hero = _LearningSpaceHero(content: content);
            final actions = _LearningSpaceActionPanel(
              content: content,
              selectedActionTitles: _selectedActionTitles,
              onActionSelected: (action) {
                setState(() {
                  _selectedActionTitles.add(action.title);
                });
              },
            );
            final roadmap = _LearningSpaceRoadmap(content: content);

            if (compact) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: AppUiTokens.studentLearningSpaceCompactHeroHeight,
                      child: hero,
                    ),
                    const SizedBox(height: AppUiTokens.spaceMd),
                    SizedBox(
                      height:
                          AppUiTokens.studentLearningSpaceCompactActionsHeight,
                      child: actions,
                    ),
                    const SizedBox(height: AppUiTokens.spaceMd),
                    SizedBox(
                      height:
                          AppUiTokens.studentLearningSpaceCompactRoadmapHeight,
                      child: roadmap,
                    ),
                  ],
                ),
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: AppUiTokens.studentPrimaryPaneFlex,
                  child: Column(
                    children: [
                      Expanded(child: hero),
                      const SizedBox(height: AppUiTokens.spaceMd),
                      Expanded(child: actions),
                    ],
                  ),
                ),
                const SizedBox(width: AppUiTokens.spaceLg),
                Expanded(
                  flex: AppUiTokens.studentSecondaryPaneFlex,
                  child: roadmap,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LearningSpaceHero extends StatelessWidget {
  const _LearningSpaceHero({required this.content});

  final _LearningSpaceContent content;

  @override
  Widget build(BuildContext context) {
    return StudentGlassPanel(
      opacity: 0.18,
      padding: const EdgeInsets.all(AppUiTokens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: () => context.go('/explore'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              StudentSectionPill(icon: content.icon, label: content.badge),
            ],
          ),
          const Spacer(),
          Icon(content.icon, size: 76, color: content.color),
          const SizedBox(height: AppUiTokens.spaceMd),
          Text(
            content.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppUiTokens.studentInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppUiTokens.spaceXs),
          Text(
            content.description,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppUiTokens.studentMuted,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningSpaceActionPanel extends StatelessWidget {
  const _LearningSpaceActionPanel({
    required this.content,
    required this.selectedActionTitles,
    required this.onActionSelected,
  });

  final _LearningSpaceContent content;
  final Set<String> selectedActionTitles;
  final ValueChanged<_LearningAction> onActionSelected;

  @override
  Widget build(BuildContext context) {
    return StudentGlassPanel(
      opacity: 0.16,
      padding: const EdgeInsets.all(AppUiTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StudentSectionPill(
            icon: Icons.touch_app_rounded,
            label: '今日可演示',
          ),
          const SizedBox(height: AppUiTokens.spaceMd),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: AppUiTokens.spaceSm,
              mainAxisSpacing: AppUiTokens.spaceSm,
              childAspectRatio:
                  AppUiTokens.studentLearningSpaceActionGridAspectRatio,
              children: [
                for (final action in content.actions)
                  _LearningActionTile(
                    action: action,
                    accent: content.color,
                    selected: selectedActionTitles.contains(action.title),
                    onTap: () => onActionSelected(action),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningActionTile extends StatelessWidget {
  const _LearningActionTile({
    required this.action,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final _LearningAction action;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppUiTokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(AppUiTokens.spaceMd),
          decoration: BoxDecoration(
            color: selected
                ? AppUiTokens.studentSuccessSoft
                : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(AppUiTokens.radiusMd),
            border: Border.all(
              color: selected
                  ? AppUiTokens.studentSuccess.withValues(alpha: 0.42)
                  : accent.withValues(alpha: 0.24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    action.icon,
                    color: selected ? AppUiTokens.studentSuccess : accent,
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppUiTokens.studentSuccess,
                      size: 20,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                selected ? '已加入' : action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppUiTokens.studentInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppUiTokens.space2xs),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppUiTokens.studentMuted,
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

class _LearningSpaceRoadmap extends StatelessWidget {
  const _LearningSpaceRoadmap({required this.content});

  final _LearningSpaceContent content;

  @override
  Widget build(BuildContext context) {
    return StudentBoundarylessSectionStage(
      icon: Icons.map_rounded,
      title: content.roadmapTitle,
      hint: content.roadmapHint,
      child: Container(
        padding: const EdgeInsets.all(AppUiTokens.spaceLg),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(AppUiTokens.radiusXl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
        ),
        child: Column(
          children: [
            for (final item in content.roadmap)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppUiTokens.spaceSm),
                  child: _RoadmapStep(item: item, accent: content.color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoadmapStep extends StatelessWidget {
  const _RoadmapStep({required this.item, required this.accent});

  final _RoadmapItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppUiTokens.radiusSm),
          ),
          child: Icon(item.icon, color: accent),
        ),
        const SizedBox(width: AppUiTokens.spaceMd),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppUiTokens.studentInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppUiTokens.space2xs),
              Text(
                item.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppUiTokens.studentMuted,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppUiTokens.spaceMd),
        StudentSectionPill(
          icon: Icons.check_circle_rounded,
          label: item.status,
          compact: true,
        ),
      ],
    );
  }
}

class _LearningSpaceContent {
  const _LearningSpaceContent({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badge,
    required this.icon,
    required this.color,
    required this.actions,
    required this.roadmapTitle,
    required this.roadmapHint,
    required this.roadmap,
  });

  final String title;
  final String subtitle;
  final String description;
  final String badge;
  final IconData icon;
  final Color color;
  final List<_LearningAction> actions;
  final String roadmapTitle;
  final String roadmapHint;
  final List<_RoadmapItem> roadmap;

  factory _LearningSpaceContent.fromId(String id) {
    return switch (id) {
      'phonics' => _phonics,
      'national-geographic' => _nationalGeographic,
      'magic-shop' => _magicShop,
      'listen' => _listen,
      'speak' => _speak,
      'write' => _write,
      'play' => _play,
      _ => _phonics,
    };
  }

  static const _phonics = _LearningSpaceContent(
    title: '自然拼读',
    subtitle: 'Phonics 分级闯关',
    description: '从字母音到高频词，把“会听”变成“会拼、会读”。',
    badge: 'Phonics',
    icon: Icons.abc_rounded,
    color: AppUiTokens.studentAccentBlue,
    actions: [
      _LearningAction(
        Icons.volume_up_rounded,
        '听字母音',
        'A / B / C 发音',
        '已播放自然拼读示范音。',
      ),
      _LearningAction(
        Icons.extension_rounded,
        '拼词小游戏',
        'cat / bag / map',
        '拼词小游戏已加入今日练习单。',
      ),
      _LearningAction(
        Icons.stars_rounded,
        '点亮徽章',
        '完成 3 关可获得',
        '自然拼读徽章会在完成后点亮。',
      ),
      _LearningAction(
        Icons.auto_stories_rounded,
        '回到教材',
        '和今日主线衔接',
        '已和今日主线教材关联。',
      ),
    ],
    roadmapTitle: '自然拼读路线',
    roadmapHint: '从声音到词块',
    roadmap: [
      _RoadmapItem(
        Icons.looks_one_rounded,
        'Level 1 字母音',
        '听清 26 个核心字母音。',
        '可学',
      ),
      _RoadmapItem(
        Icons.looks_two_rounded,
        'Level 2 CVC 拼读',
        '练习 cat、bag、map 这类短词。',
        '推荐',
      ),
      _RoadmapItem(
        Icons.looks_3_rounded,
        'Level 3 高频词',
        '把高频词变成可自动识别的词块。',
        '待解锁',
      ),
    ],
  );

  static const _nationalGeographic = _LearningSpaceContent(
    title: '国家地理 PM',
    subtitle: '真实图片分级阅读',
    description: '用高质量图片和短句阅读，帮孩子建立英语里的真实世界。',
    badge: '分级阅读',
    icon: Icons.public_rounded,
    color: AppUiTokens.studentSuccess,
    actions: [
      _LearningAction(
        Icons.photo_library_rounded,
        '看图读句',
        '图片辅助理解',
        '已打开图片阅读演示。',
      ),
      _LearningAction(Icons.headphones_rounded, '听原声', '磨耳朵输入', '已播放分级阅读原声。'),
      _LearningAction(Icons.bookmark_rounded, '收藏绘本', '加入我的书架', '这本绘本已加入书架。'),
      _LearningAction(Icons.task_alt_rounded, '读后小测', '3 题轻测验', '读后小测已准备好。'),
    ],
    roadmapTitle: '阅读路线',
    roadmapHint: '从图片理解到独立阅读',
    roadmap: [
      _RoadmapItem(Icons.image_rounded, 'Picture Walk', '先看图片猜内容。', '可学'),
      _RoadmapItem(
        Icons.menu_book_rounded,
        'Guided Reading',
        '跟着原声读关键句。',
        '推荐',
      ),
      _RoadmapItem(Icons.quiz_rounded, 'Mini Quiz', '用 3 道小题确认理解。', '可做'),
    ],
  );

  static const _magicShop = _LearningSpaceContent(
    title: '魔法商店',
    subtitle: '星币兑换与装扮',
    description: '星币只用于应用内虚拟奖励，形成安全、可控的学习激励闭环。',
    badge: '星币',
    icon: Icons.card_giftcard_rounded,
    color: AppUiTokens.studentAccentYellow,
    actions: [
      _LearningAction(
        Icons.face_retouching_natural_rounded,
        '头像框',
        '16 星币起',
        '头像框预览已打开。',
      ),
      _LearningAction(Icons.pets_rounded, '伴学宠物', '喂养和装扮', '伴学宠物今天吃到一颗星星。'),
      _LearningAction(
        Icons.workspace_premium_rounded,
        '班级荣誉',
        '共同点亮',
        '星币会计入班级荣誉树。',
      ),
      _LearningAction(
        Icons.receipt_long_rounded,
        '星币账单',
        '家长可查看',
        '星币账单已记录本次演示行为。',
      ),
    ],
    roadmapTitle: '星币规则',
    roadmapHint: '只鼓励学习，不鼓励刷币',
    roadmap: [
      _RoadmapItem(Icons.flag_rounded, '今日主线高收益', '优先完成作业获得主要星币。', '核心'),
      _RoadmapItem(Icons.timer_rounded, '自选练习递减', '听说写玩不会无限刷币。', '安全'),
      _RoadmapItem(Icons.lock_rounded, '不可兑换实物', '避免合规和攀比风险。', '已保护'),
    ],
  );

  static const _listen = _LearningSpaceContent(
    title: '听',
    subtitle: '沉浸式磨耳朵',
    description: '不强制评分，像听电台一样接触儿歌、绘本原声和课堂音频。',
    badge: 'Listen',
    icon: Icons.headphones_rounded,
    color: AppUiTokens.studentAccentBlue,
    actions: [
      _LearningAction(Icons.music_note_rounded, '儿歌台', '1 分钟一首', '儿歌台开始播放。'),
      _LearningAction(Icons.menu_book_rounded, '绘本原声', '边看边听', '绘本原声已播放。'),
      _LearningAction(Icons.repeat_rounded, '循环听', '睡前磨耳朵', '已加入循环听单。'),
      _LearningAction(Icons.favorite_rounded, '收藏', '喜欢就存下', '已收藏到我的听单。'),
    ],
    roadmapTitle: '今日听力输入',
    roadmapHint: '轻压力，高频接触',
    roadmap: [
      _RoadmapItem(
        Icons.play_circle_rounded,
        'Warm-up Song',
        '先用儿歌进入英语状态。',
        '可听',
      ),
      _RoadmapItem(Icons.hearing_rounded, 'Story Audio', '听绘本原声建立语感。', '推荐'),
      _RoadmapItem(Icons.nightlight_round, 'Bedtime Loop', '睡前循环 5 分钟。', '可选'),
    ],
  );

  static const _speak = _LearningSpaceContent(
    title: '说',
    subtitle: '情景化开口训练',
    description: '从机械跟读走向真实表达，用角色扮演和 AI 对话鼓励孩子开口。',
    badge: 'Speak',
    icon: Icons.record_voice_over_rounded,
    color: AppUiTokens.studentAccentOrange,
    actions: [
      _LearningAction(
        Icons.theater_comedy_rounded,
        '角色扮演',
        '餐厅点餐',
        '已进入餐厅点餐演示。',
      ),
      _LearningAction(Icons.smart_toy_rounded, 'AI 对话', '认识新朋友', 'AI 小伙伴已经上线。'),
      _LearningAction(
        Icons.movie_creation_rounded,
        '视频配音',
        '给动画配一句',
        '配音片段已准备好。',
      ),
      _LearningAction(
        Icons.emoji_events_rounded,
        '开口徽章',
        '勇敢说出来',
        '开口徽章已点亮预览。',
      ),
    ],
    roadmapTitle: '口语路线',
    roadmapHint: '先敢说，再说准',
    roadmap: [
      _RoadmapItem(Icons.mic_rounded, 'Repeat', '跟着标准音大胆读。', '基础'),
      _RoadmapItem(Icons.forum_rounded, 'Role Play', '在场景里说完整句。', '推荐'),
      _RoadmapItem(Icons.psychology_rounded, 'Free Talk', 'AI 根据回答继续追问。', '进阶'),
    ],
  );

  static const _write = _LearningSpaceContent(
    title: '写',
    subtitle: '作品上传与多模态表达',
    description: '把线下练习册、手工作品和字母描红接入线上成长记录。',
    badge: 'Write',
    icon: Icons.edit_note_rounded,
    color: AppUiTokens.studentSuccess,
    actions: [
      _LearningAction(
        Icons.add_a_photo_rounded,
        '拍照上传',
        '练习册/作品',
        '作品已加入成长相册。',
      ),
      _LearningAction(Icons.draw_rounded, '字母描红', '三期重点', '描红练习预览已打开。'),
      _LearningAction(
        Icons.image_search_rounded,
        '拍照识物',
        '看见就学',
        '拍照识物会生成单词卡。',
      ),
      _LearningAction(
        Icons.workspace_premium_rounded,
        '作品盖章',
        '老师鼓励',
        '老师盖章位已预览。',
      ),
    ],
    roadmapTitle: '作品路线',
    roadmapHint: '线上线下连接起来',
    roadmap: [
      _RoadmapItem(Icons.photo_camera_rounded, 'Upload', '把线下作品收进成长档案。', '可用'),
      _RoadmapItem(Icons.gesture_rounded, 'Trace', '低龄字母描红放到三期。', '规划'),
      _RoadmapItem(
        Icons.local_florist_rounded,
        'Showcase',
        '优秀作品进入班级长廊。',
        '可展示',
      ),
    ],
  );

  static const _play = _LearningSpaceContent(
    title: '玩',
    subtitle: '错词小游戏与星币消费',
    description: '把当天作业里的错词变成小游戏，让薄弱点复习不再像考试。',
    badge: 'Play',
    icon: Icons.extension_rounded,
    color: AppUiTokens.studentAccentOrange,
    actions: [
      _LearningAction(
        Icons.grid_3x3_rounded,
        '错词消消乐',
        'dirty / ears',
        '错词消消乐已生成。',
      ),
      _LearningAction(Icons.style_rounded, '翻翻卡', '听音翻词', '翻翻卡已洗牌。'),
      _LearningAction(Icons.toys_rounded, '单词积木', '拖拽拼词', '单词积木开始闯关。'),
      _LearningAction(Icons.pets_rounded, '喂养宠物', '消耗星币', '伴学宠物开心地跳了一下。'),
    ],
    roadmapTitle: '游戏化复习',
    roadmapHint: '错词自动进入复习池',
    roadmap: [
      _RoadmapItem(Icons.error_outline_rounded, 'Collect', 'AI 评审沉淀错音词。', '自动'),
      _RoadmapItem(Icons.casino_rounded, 'Play', '错词变成可玩关卡。', '可玩'),
      _RoadmapItem(Icons.check_circle_rounded, 'Master', '连续答对后移出错词本。', '闭环'),
    ],
  );
}

class _LearningAction {
  const _LearningAction(this.icon, this.title, this.subtitle, this.feedback);

  final IconData icon;
  final String title;
  final String subtitle;
  final String feedback;
}

class _RoadmapItem {
  const _RoadmapItem(this.icon, this.title, this.subtitle, this.status);

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
}
