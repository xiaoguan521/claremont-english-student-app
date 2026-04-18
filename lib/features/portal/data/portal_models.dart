enum ActivityStatus { active, reviewPending, completed }

enum TaskKind { dubbing, recording, phonics }

enum TaskReviewStatus { checked, pendingReview, inProgress }

class PortalTask {
  const PortalTask({
    required this.id,
    required this.title,
    required this.kind,
    required this.reviewStatus,
    required this.previewAsset,
  });

  final String id;
  final String title;
  final TaskKind kind;
  final TaskReviewStatus reviewStatus;
  final String previewAsset;
}

class PortalActivity {
  const PortalActivity({
    required this.id,
    required this.title,
    required this.className,
    required this.dateLabel,
    required this.status,
    required this.reviewCount,
    required this.inspectCount,
    required this.urgeCount,
    required this.completionRate,
    required this.tasks,
  });

  final String id;
  final String title;
  final String className;
  final String dateLabel;
  final ActivityStatus status;
  final int reviewCount;
  final int inspectCount;
  final int urgeCount;
  final double completionRate;
  final List<PortalTask> tasks;
}

const mockPortalActivities = [
  PortalActivity(
    id: 'h-7day',
    title: '7天打卡活动',
    className: '精品英语H班',
    dateLabel: '4.18 - 4.24',
    status: ActivityStatus.active,
    reviewCount: 3,
    inspectCount: 0,
    urgeCount: 5,
    completionRate: 1,
    tasks: [
      PortalTask(
        id: 'h-1',
        title: '8 能和不能',
        kind: TaskKind.dubbing,
        reviewStatus: TaskReviewStatus.checked,
        previewAsset: '视频配音',
      ),
      PortalTask(
        id: 'h-2',
        title: 'Module 7-2',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.checked,
        previewAsset: '录音',
      ),
      PortalTask(
        id: 'h-3',
        title: 'Module 7-3',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.checked,
        previewAsset: '录音',
      ),
      PortalTask(
        id: 'h-4',
        title: 'Module 8-1',
        kind: TaskKind.phonics,
        reviewStatus: TaskReviewStatus.pendingReview,
        previewAsset: '自然拼读',
      ),
    ],
  ),
  PortalActivity(
    id: 'z-7day',
    title: '7天打卡活动',
    className: '精品英语Z班',
    dateLabel: '4.18 - 4.24',
    status: ActivityStatus.active,
    reviewCount: 3,
    inspectCount: 0,
    urgeCount: 5,
    completionRate: 0.86,
    tasks: [
      PortalTask(
        id: 'z-1',
        title: 'Module 5-1',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.inProgress,
        previewAsset: '录音',
      ),
      PortalTask(
        id: 'z-2',
        title: 'Module 5-2',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.checked,
        previewAsset: '录音',
      ),
      PortalTask(
        id: 'z-3',
        title: '课堂短剧',
        kind: TaskKind.dubbing,
        reviewStatus: TaskReviewStatus.pendingReview,
        previewAsset: '视频配音',
      ),
    ],
  ),
  PortalActivity(
    id: 't-7day',
    title: '7天打卡活动',
    className: '精品英语T班',
    dateLabel: '4.17 - 4.23',
    status: ActivityStatus.reviewPending,
    reviewCount: 6,
    inspectCount: 0,
    urgeCount: 6,
    completionRate: 0.72,
    tasks: [
      PortalTask(
        id: 't-1',
        title: 'Module 3-1',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.pendingReview,
        previewAsset: '录音',
      ),
      PortalTask(
        id: 't-2',
        title: 'Module 3-2',
        kind: TaskKind.recording,
        reviewStatus: TaskReviewStatus.pendingReview,
        previewAsset: '录音',
      ),
      PortalTask(
        id: 't-3',
        title: '元音拼读',
        kind: TaskKind.phonics,
        reviewStatus: TaskReviewStatus.checked,
        previewAsset: '自然拼读',
      ),
    ],
  ),
];
